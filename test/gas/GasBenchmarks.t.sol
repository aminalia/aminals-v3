// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {Gene} from "src/Gene.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {BreedingTestBase} from "../base/BreedingTestBase.sol";

/**
 * @title GasBenchmarks
 * @notice Gas benchmarking for critical operations
 * @dev Run with: forge test --match-contract GasBenchmarks --gas-report
 */
contract GasBenchmarks is BreedingTestBase {
    using TestHelpers for *;
    
    Gene public geneContract;
    address public user1;
    
    function setUp() public override {
        super.setUp();
        user1 = makeAddr("user1");
        vm.deal(user1, 10 ether);
        geneContract = new Gene(user1, "GasBench", "GAS", "https://gas.test/");
    }
    
    function test_Gas_AminalCreation() public {
        uint256 gasBefore = gasleft();
        
        address aminal = factory.createAminalWithGenes(
            "GasTest",
            "GAS",
            "Gas benchmark aminal",
            "gas.json",
            TestHelpers.dragonTraits()
        );
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas for Aminal creation:", gasUsed);
        _recordGas("AminalCreation", gasUsed);
    }
    
    function test_Gas_AminalInitialization() public {
        Aminal aminal = new Aminal("GasTest", "GAS", BASE_URI, TestHelpers.dragonTraits());
        
        uint256 gasBefore = gasleft();
        aminal.initialize("gas-test.json");
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for Aminal initialization:", gasUsed);
        _recordGas("AminalInitialization", gasUsed);
    }
    
    function test_Gas_FeedingAminal() public {
        uint256 gasBefore = gasleft();
        _feedAminal(user1, address(parent1), 1 ether);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for feeding Aminal:", gasUsed);
        _recordGas("FeedingAminal", gasUsed);
    }
    
    function test_Gas_BreedingProposal() public {
        _feedAminal(breederA, address(parent1), 0.5 ether);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Gas test breeding",
            "gas-breeding.json"
        );
        
        uint256 gasBefore = gasleft();
        vm.prank(breederA);
        parent1.useSkill(address(breedingSkill), proposalData);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for breeding proposal:", gasUsed);
        _recordGas("BreedingProposal", gasUsed);
    }
    
    function test_Gas_VotingOnTraits() public {
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        _feedAminal(voter1, address(parent1), 0.1 ether);
        
        AminalBreedingVote.GeneType[] memory types = new AminalBreedingVote.GeneType[](8);
        bool[] memory votes = new bool[](8);
        
        for (uint i = 0; i < 8; i++) {
            types[i] = AminalBreedingVote.GeneType(i);
            votes[i] = i % 2 == 0;
        }
        
        uint256 gasBefore = gasleft();
        _voteOnTraits(voter1, ticketId, types, votes);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for voting on all traits:", gasUsed);
        _recordGas("VotingAllTraits", gasUsed);
    }
    
    function test_Gas_GeneProposal() public {
        uint256 ticketId = _createBreedingTicket();
        _feedAminal(user1, address(parent1), 0.02 ether);
        
        geneContract.mint(user1, "back", "Dragon Wings", TestHelpers.DRAGON_WINGS_SVG, "Majestic dragon wings");
        
        uint256 gasBefore = gasleft();
        vm.prank(user1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1
        );
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for gene proposal:", gasUsed);
        _recordGas("GeneProposal", gasUsed);
    }
    
    function test_Gas_BreedingExecution() public {
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Simple vote to allow breeding
        _feedAminal(voter1, address(parent1), 0.1 ether);
        AminalBreedingVote.GeneType[] memory types = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        types[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        _voteOnTraits(voter1, ticketId, types, votes);
        
        _warpToExecutionPhase();
        
        uint256 gasBefore = gasleft();
        address child = breedingVote.executeBreeding(ticketId);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas for breeding execution:", gasUsed);
        _recordGas("BreedingExecution", gasUsed);
    }
    
    function test_Gas_MultipleFeedings() public {
        uint256 totalGas = 0;
        
        for (uint i = 0; i < 10; i++) {
            uint256 gasBefore = gasleft();
            _feedAminal(user1, address(parent1), 0.1 ether);
            totalGas += gasBefore - gasleft();
        }
        
        console2.log("Average gas for 10 feedings:", totalGas / 10);
        _recordGas("AverageFeedingGas", totalGas / 10);
    }
    
    // Helper to record gas usage for later analysis
    mapping(string => uint256) private gasUsage;
    
    function _recordGas(string memory operation, uint256 gas) private {
        gasUsage[operation] = gas;
    }
    
    function getGasReport() external view {
        console2.log("=== Gas Usage Report ===");
        console2.log("AminalCreation:", gasUsage["AminalCreation"]);
        console2.log("AminalInitialization:", gasUsage["AminalInitialization"]);
        console2.log("FeedingAminal:", gasUsage["FeedingAminal"]);
        console2.log("BreedingProposal:", gasUsage["BreedingProposal"]);
        console2.log("VotingAllTraits:", gasUsage["VotingAllTraits"]);
        console2.log("GeneProposal:", gasUsage["GeneProposal"]);
        console2.log("BreedingExecution:", gasUsage["BreedingExecution"]);
        console2.log("AverageFeedingGas:", gasUsage["AverageFeedingGas"]);
    }
}