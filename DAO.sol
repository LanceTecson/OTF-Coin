// SPDX-License-Identifier: GPL-3.0-or-later
// Lance Tecson lat4nyv

pragma solidity ^0.8.21;

import "./IDAO.sol";
import "./IERC721Metadata.sol";
import "./IERC721.sol";
import "./Strings.sol";
import "./NFTManager.sol";

contract DAO is IDAO{
    constructor(){
        tokens = address(new NFTManager());
        curator = msg.sender;
        requestMembership();
    }

    mapping(uint => Proposal) public override proposals;
    uint public constant override minProposalDebatePeriod = 600;
    address public immutable override tokens;
    string public constant override purpose = "Growth & Development!";
    mapping(address => mapping(uint => bool)) public override votedYes;
    mapping(address => mapping(uint => bool)) public override votedNo;
    uint public override numberOfProposals;
    string public constant override howToJoin = "Move Chicago, Illinois; preferably 65th or 64th street, but certainly not 63rd!";
    uint public override reservedEther;
    address public immutable override curator;

    receive() payable external{
    }

    function newProposal
    (address recipient, uint amount, string memory description, uint debatingPeriod) 
    public payable override returns (uint){
        require(isMember(msg.sender), "LLX!");
        require(debatingPeriod >= minProposalDebatePeriod, "Insufficient deliberation duration!");
        require(amount + reservedEther <= address(this).balance, "DAO defies Newton's 4th law!");

        uint ID = numberOfProposals;
        numberOfProposals++;
        reservedEther += amount;
        proposals[ID] = Proposal(recipient, amount, description, block.timestamp + debatingPeriod, true, false, 0, 0, msg.sender);
        emit NewProposal(ID, recipient, amount, description);
        return ID;
    }

    function vote(uint proposalID, bool supportsProposal) public override{
        require(isMember(msg.sender), "LLX!");
        require(proposalID < numberOfProposals, "Invalid proposal!");
        require(proposals[proposalID].open, "Proposal closed!");
        require(block.timestamp < proposals[proposalID].votingDeadline, "Voting over!");
        require(!votedYes[msg.sender][proposalID] && !votedNo[msg.sender][proposalID], "Already voted!");

        if (supportsProposal){
            votedYes[msg.sender][proposalID] = true;
            proposals[proposalID].yea++;
        }
        else{
            votedNo[msg.sender][proposalID] = true;
            proposals[proposalID].nay++;
        }
        emit Voted(proposalID, supportsProposal, msg.sender);
    }

    function closeProposal(uint proposalID) public override{
        require(isMember(msg.sender), "LLX!");
        require(proposalID < numberOfProposals, "Invalid proposal!");
        require(proposals[proposalID].open, "Already closed!");
        require(proposals[proposalID].votingDeadline < block.timestamp, "Not yet deadline!");

        if (proposals[proposalID].yea > proposals[proposalID].nay){
            proposals[proposalID].proposalPassed = true;
            (bool success, ) = payable(proposals[proposalID].recipient).call{value: proposals[proposalID].amount}("");
            require(success, "Failed to transfer ETH");
        }
        reservedEther -= proposals[proposalID].amount;
        proposals[proposalID].open = false; 
        emit ProposalClosed(proposalID, proposals[proposalID].proposalPassed);
    }

    function isMember(address who) public override view returns (bool){
        return NFTManager(tokens).balanceOf(who) > 0;
    }

    function addMember(address who) public override{
        require(isMember(msg.sender), "LLX!");

        NFTManager(tokens).mintWithURI(who, substring(Strings.toHexString(who),2,34));
    }

    function requestMembership() public override{
        require(!isMember(msg.sender), "Already registered nurse!");

        NFTManager(tokens).mintWithURI(msg.sender, substring(Strings.toHexString(msg.sender),2,34));
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool){
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IDAO).interfaceId;
    }

    function substring(string memory str, uint startIndex, uint endIndex) public pure returns (string memory){
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++)
            result[i-startIndex] = strBytes[i];
        return string(result);
    }
}