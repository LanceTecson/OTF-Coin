// SPDX-License-Identifier: GPL-3.0-or-later
// Lance Tecson lat4nyv

pragma solidity ^0.8.21;

import "./IAuctioneer.sol";
import "./NFTManager.sol";
import "./ERC721.sol";

contract Auctioneer is IAuctioneer{
    address public override nftmanager;
    address public override deployer;
    constructor(){
        nftmanager = address(new NFTManager());
        deployer = msg.sender;
    }
    uint public override num_auctions;
    uint public override totalFees;
    uint public override uncollectedFees;
    mapping(uint => Auction) public override auctions;
    function collectFees() external{
        require(uncollectedFees > 0, "Fees already collected!");
        (bool success, ) = payable(deployer).call{value: uncollectedFees}("");
        require(success, "Failed to transfer ETH");
        uncollectedFees = 0;
    }

    function startAuction(uint m, uint h, uint d, string memory data, uint reserve, uint nftid) external 
    returns (uint){
        require(m + h + d > 0, "Duration cannot be 0!");
        require(keccak256(bytes(data)) != keccak256(""), "Data cannot be empty!");
        for (uint i; i < num_auctions; i++){
            if (auctions[i].nftid == nftid) require(!auctions[i].active, "That NFT is already on auction!");
        }
        require(INFTManager(nftmanager).ownerOf(nftid) == msg.sender, "You do not own this NFT!");

        emit auctionStartEvent(num_auctions);
        INFTManager(nftmanager).transferFrom(msg.sender, address(this), nftid);
        uint time = block.timestamp + 60 * m + 3600 * h + 86400 * d;
        auctions[num_auctions] = Auction(num_auctions, 0, data, reserve, address(0), msg.sender, nftid, time, true);
        uint temp = num_auctions;
        num_auctions++;
        return temp;
    }

    function closeAuction(uint id) external{
        require(id <= num_auctions, "Auction does not exist!");
        require(auctionTimeLeft(id) == 0, "Auction not over!");
        require(auctions[id].active, "Auction must be active!");
        if (auctions[id].winner != address(0)){
            (bool success, ) = payable(deployer).call{value: auctions[id].highestBid * 99 / 100}("");
            require(success, "Failed to transfer ETH");
            INFTManager(nftmanager).transferFrom(address(this), auctions[id].winner, auctions[id].nftid);
            emit auctionCloseEvent(id);
            totalFees = auctions[id].highestBid * 1 / 100;
            uncollectedFees = auctions[id].highestBid * 1 / 100;
        }
        
        emit auctionCloseEvent(id);
        totalFees = auctions[id].highestBid * 1 / 100;
        uncollectedFees = auctions[id].highestBid * 1 / 100;
        auctions[id].active = false;
    }

    function placeBid(uint id) payable external{
        require(id <= num_auctions, "Auction does not exist!");
        require(msg.value > auctions[id].highestBid, "Must bid higher!");
        require(auctionTimeLeft(id) > 0, "Auction out of time!");
        require(auctions[id].active, "Auction must be active!");
        if (auctions[id].winner != address(0)){
            (bool success, ) = payable(auctions[id].winner).call{value: auctions[id].highestBid}("");
            require(success, "Failed to transfer ETH");
        }
        
        
        emit higherBidEvent(id);
        auctions[id].num_bids++;
        auctions[id].highestBid = msg.value;
        auctions[id].winner = msg.sender;
    }

    function auctionTimeLeft(uint id) public view returns (uint){
        require(id <= num_auctions, "Auction does not exist!");

        if (auctions[id].endTime > block.timestamp) return auctions[id].endTime - block.timestamp;
        return 0;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IAuctioneer).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}