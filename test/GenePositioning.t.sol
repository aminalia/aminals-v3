// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "../src/Aminal.sol";
import {AminalFactory} from "../src/AminalFactory.sol";
import {Gene} from "../src/Gene.sol";
import {AminalRenderer} from "../src/AminalRenderer.sol";
import {IGenes} from "../src/interfaces/IGenes.sol";
import {AminalBreedingVote} from "../src/AminalBreedingVote.sol";
import {BreedingSkill} from "../src/skills/BreedingSkill.sol";

contract GenePositioningTest is Test {
    AminalFactory public factory;
    AminalBreedingVote public breedingVote;
    BreedingSkill public breedingSkill;
    Gene public gene;
    AminalRenderer public renderer;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    Aminal public parent1;
    Aminal public parent2;
    
    // Implement IERC721Receiver to receive NFTs
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function setUp() public {
        // Deploy contracts
        renderer = new AminalRenderer();
        
        // Create parent data
        AminalFactory.ParentData memory firstParent = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            genes: IGenes.Genes({
                back: "Dragon Wings",
                arm: "Strong Arms",
                tail: "Dragon Tail",
                ears: "Dragon Ears",
                body: "Dragon Body",
                face: "Dragon Face",
                mouth: "Dragon Mouth",
                misc: ""
            })
        });
        
        AminalFactory.ParentData memory secondParent = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "ipfs://eve",
            genes: IGenes.Genes({
                back: "Angel Wings",
                arm: "Gentle Arms",
                tail: "Fluffy Tail",
                ears: "Bunny Ears",
                body: "Soft Body",
                face: "Kind Face",
                mouth: "Sweet Mouth",
                misc: ""
            })
        });
        
        // Deploy factory
        factory = new AminalFactory(address(this), firstParent, secondParent);
        
        // Deploy breeding contracts
        breedingVote = new AminalBreedingVote(address(factory), address(0)); // We'll set skill after
        breedingSkill = new BreedingSkill(address(factory), address(breedingVote));
        // Update breeding vote with actual skill address
        breedingVote = new AminalBreedingVote(address(factory), address(breedingSkill));
        
        // Set breeding vote contract in factory
        factory.setBreedingVoteContract(address(breedingVote));
        
        // Deploy gene contract
        gene = new Gene(address(this), "Test Genes", "GENE", "https://example.com/");
        
        // Get parent Aminals
        parent1 = Aminal(payable(factory.firstParent()));
        parent2 = Aminal(payable(factory.secondParent()));
        
        // Give users ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // Feed parents to give users love
        vm.prank(user1);
        (bool success1,) = address(parent1).call{value: 10 ether}("");
        assertTrue(success1);
        
        vm.prank(user2);
        (bool success2,) = address(parent2).call{value: 10 ether}("");
        assertTrue(success2);
    }
    
    function test_GeneProposalWithPositions() public {
        // Create breeding ticket
        vm.startPrank(user1);
        bytes memory proposeData = abi.encodeCall(
            BreedingSkill.createProposal,
            (address(parent2), "Test child", "ipfs://child")
        );
        parent1.useSkill(address(breedingSkill), proposeData);
        vm.stopPrank();
        
        // Accept breeding
        vm.startPrank(user2);
        bytes memory acceptData = abi.encodeCall(
            BreedingSkill.acceptProposal,
            (1) // proposalId starts at 1
        );
        parent2.useSkill(address(breedingSkill), acceptData);
        vm.stopPrank();
        
        uint256 ticketId = 1;
        
        // Create genes with specific positions
        uint256 backGeneId = gene.mint(
            address(this),
            "back",
            "Rainbow Wings",
            '<rect x="0" y="0" width="100" height="100" fill="rainbow"/>',
            "Rainbow wings"
        );
        
        uint256 bodyGeneId = gene.mint(
            address(this),
            "body",
            "Crystal Body",
            '<rect x="0" y="0" width="80" height="80" fill="crystal"/>',
            "Crystal body"
        );
        
        // Propose genes with custom positions
        vm.startPrank(user1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(gene),
            backGeneId,
            -20,  // x: offset to left
            -10,  // y: offset up
            240,  // width: larger than default
            220   // height: larger than default
        );
        
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BODY,
            address(gene),
            bodyGeneId,
            40,   // x: custom position
            30,   // y: custom position
            120,  // width: custom size
            140   // height: custom size
        );
        vm.stopPrank();
        
        // Skip to voting phase
        vm.warp(block.timestamp + 3 days + 1);
        
        // Vote for proposed genes
        vm.prank(user1);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        vm.prank(user1);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BODY, 0);
        
        // Vote to proceed
        vm.prank(user1);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Skip to execution phase
        vm.warp(block.timestamp + 4 days + 1);
        
        // Execute breeding
        breedingVote.executeBreeding(ticketId);
        
        // Get the child
        (,,,,,,,, address childAddress,) = breedingVote.tickets(ticketId);
        Aminal child = Aminal(payable(childAddress));
        
        // Verify positions were set correctly
        (int16 backX, int16 backY, uint16 backWidth, uint16 backHeight) = child.genePositions(child.GENE_BACK());
        assertEq(backX, -20, "Back X position");
        assertEq(backY, -10, "Back Y position");
        assertEq(backWidth, 240, "Back width");
        assertEq(backHeight, 220, "Back height");
        
        (int16 bodyX, int16 bodyY, uint16 bodyWidth, uint16 bodyHeight) = child.genePositions(child.GENE_BODY());
        assertEq(bodyX, 40, "Body X position");
        assertEq(bodyY, 30, "Body Y position");
        assertEq(bodyWidth, 120, "Body width");
        assertEq(bodyHeight, 140, "Body height");
        
        // Other genes should have default positions
        (,, uint16 armWidth,) = child.genePositions(child.GENE_ARM());
        assertEq(armWidth, 160, "Arm should have default width");
    }
    
    function test_DefaultPositionsForParentGenes() public {
        // Create Aminal directly with factory
        IGenes.Genes memory traits = IGenes.Genes({
            back: "Test Back",
            arm: "Test Arm",
            tail: "Test Tail",
            ears: "Test Ears",
            body: "Test Body",
            face: "Test Face",
            mouth: "Test Mouth",
            misc: ""
        });
        
        address aminalAddress = factory.createAminalWithGenes(
            "Test Aminal",
            "TEST",
            "A test aminal",
            "ipfs://test",
            traits
        );
        
        Aminal testAminal = Aminal(payable(aminalAddress));
        
        // Check all positions are set to defaults
        (int16 x, int16 y, uint16 width, uint16 height) = testAminal.genePositions(testAminal.GENE_BODY());
        assertEq(x, 50, "Body default X");
        assertEq(y, 50, "Body default Y");
        assertEq(width, 100, "Body default width");
        assertEq(height, 100, "Body default height");
        
        (x, y, width, height) = testAminal.genePositions(testAminal.GENE_EARS());
        assertEq(x, 50, "Ears default X");
        assertEq(y, 0, "Ears default Y");
        assertEq(width, 100, "Ears default width");
        assertEq(height, 60, "Ears default height");
    }
}