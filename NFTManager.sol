// SPDX-License-Identifier: GPL-3.0-or-later
// Lance Tecson lat4nyv

pragma solidity ^0.8.21;

import "./INFTManager.sol";
import "./ERC721.sol";

contract NFTManager is INFTManager, ERC721{
    constructor() ERC721("KingVonCoin", "KVC"){}

    uint tokens = 0;
    mapping (uint => string) public map;
    mapping (string => bool) public minted;
    function mintWithURI(address _to, string memory _uri) public override returns (uint){
        require(!minted[_uri]);
        _safeMint(_to, tokens);
        map[tokens] = string.concat(_baseURI(), _uri);
        minted[_uri] = true;
        uint temp = tokens;
        tokens++;
        return temp;
    }

    function mintWithURI(string memory _uri) external returns (uint){
        return mintWithURI(msg.sender, _uri);
    }

    function count() external view returns (uint){
        return tokens;
    }
            
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, ERC721) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(INFTManager).interfaceId;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://andromeda.cs.virginia.edu/ccc/ipfs/files/";
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
        _requireMinted(tokenId);
        return map[tokenId];
    }
}