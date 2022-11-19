// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract StackunderflowToken is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Stackunderflow Token", "STK") {}

    // function safeMint(address to, uint256 tokenId) public onlyOwner {
    //     _safeMint(to, tokenId);
    // }

    function mintNFT(address account, string memory metadataURI) public payable returns (uint256){
        //require(msg.value == 0.1 ether, "Not enough funds to mint.");
        uint256 newTokenId = _tokenIds.current();
        _safeMint(account, newTokenId);
        _setTokenURI(newTokenId, metadataURI);
        
        _tokenIds.increment();
        return newTokenId;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public  override {}
}