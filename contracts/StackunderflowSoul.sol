// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "erc721a/contracts/ERC721A.sol";

interface IStackunderflowSoul {
    // voucher for user to levelup
    struct NFTVoucher {
        uint256 tokenId; 
        uint256 category;
        uint256 newLevel; 
    }
    // the owner of the StackunderflowSoul nft
    struct SBT {
        address soul;
        uint256 category;
        uint256[] categories;
        uint256 level;
        address collection;
        uint256 collectionTokenId;
        string tokenUri;
    }

    event Minted(address indexed soul, uint256 indexed tokenId, uint256 category);
    event Destroyed(address indexed soul, uint256 indexed tokenId);

    // we don't include categories array here since it may be too costly
    event SoulChanged(
        address indexed soul,
        uint256 indexed tokenId,
        uint256 category,
        uint256 indexed level,
        address collection,
        uint256 collectionTokenId
    );
    event CategoriesChanged(address indexed soul, uint256 indexed tokenId, uint256[] categories);
    event TokenBaseURIUpdated(string baseUri);

    function categoryOf(uint256 tokenId) external view returns (uint256);
    function levelOf(uint256 tokenId) external view returns (uint256);
    //function levelOfCategory(uint256 tokenId, uint256 category) external view returns (uint256);
    function soulOf(uint256 tokenId) external view returns (address);
    function collectionOf(uint256 tokenId) external view returns (address);
    function collectionTokenIdOf(uint256 tokenId) external view returns (uint256);

    // specify the initial category
    //function mint(uint256 category) external;
    function mint(string memory metadataURI) external;

    // Level up the soooul given signature from the core team
    // user can only level up the primary category
    function levelUp(uint256 tokenId, uint256 newLevel, NFTVoucher calldata voucher, bytes calldata signature) external;

    // set primary category 
    function setPrimaryCategory(uint256 tokenId, uint256 primaryCategory) external;
    function setCategories(uint256 tokenId, uint256[] memory categories) external;

    // bind the soooul with specific NFT to upgrade its image
    // input 0 address to unbind
    function bind(uint256 tokenId, address collection, uint256 collectionTokenId) external;
}


contract StackunderflowSoul is Ownable, ERC721A, EIP712, IStackunderflowSoul {

    string baseTokenURI;

    mapping (uint256 => SBT) public tokenIdToSBT;
    // soul address to sbt
    mapping (address => SBT) public soulToSBT;
    mapping (address => uint256) public soulToTokenId;

    modifier onlySoul (uint256 tokenId) {
        require(_msgSender() == tokenIdToSBT[tokenId].soul, "Only the original soul can access this function.");
        _;
    }

    // --- Start of Soulbond disabled functionalities ---
    error Soulbond();

    /// @notice The following functions were disabled to make the token Soulbond. Calling it will revert
    function approve(address, uint256) public payable override {
        revert Soulbond();
    }
    function getApproved(uint256) public pure override returns (address) {
        revert Soulbond();
    }
    function setApprovalForAll(address, bool) public pure override {
        revert Soulbond();
    }
    function isApprovedForAll(address, address) public pure override returns (bool) {
        revert Soulbond();
    }
    function transferFrom(address, address, uint256) public payable override {
        revert Soulbond();
    }
    function safeTransferFrom(address, address, uint256) public payable override {
        revert Soulbond();
    }
    function safeTransferFrom(address, address, uint256, bytes memory) public payable override {
        revert Soulbond();
    }
    // --- End of Soulbond disabled functionalities ---


    constructor(string memory _name, string memory _symbol, string memory _baseTokenURI) ERC721A(_name, _symbol) EIP712(_name, "1") {
        baseTokenURI = _baseTokenURI;
    }

    // add virtual if it's overridable
    function categoryOf(uint256 tokenId) external override view returns (uint256) {
        return tokenIdToSBT[tokenId].category;
    }
    function levelOf(uint256 tokenId) external override view returns (uint256) {
        return tokenIdToSBT[tokenId].level;
    }
    function soulOf(uint256 tokenId) external override view returns (address) {
        return tokenIdToSBT[tokenId].soul;
    }
    function collectionOf(uint256 tokenId) external override view returns (address){
        return tokenIdToSBT[tokenId].collection;
    }
    function collectionTokenIdOf(uint256 tokenId) external override view returns (uint256){
        return tokenIdToSBT[tokenId].collectionTokenId;
    }

    // specify the initial category
    function mint(string memory metadataURI) external override {
        require(soulToSBT[msg.sender].soul == address(0), "Our user should only have one SBT");
        
        uint256 category = 1;
        
        uint256[] memory categories = new uint256[](1);
        categories[0] = category;

        SBT memory sbt = SBT(msg.sender, category, categories, 0, address(0), 999999, metadataURI);
        soulToSBT[msg.sender] = sbt; // one people can only have one sbt
        uint256 curTokenId = _nextTokenId();
        tokenIdToSBT[curTokenId] = sbt;
        soulToTokenId[msg.sender] = curTokenId;

        super._safeMint(msg.sender, 1);

        emit Minted(msg.sender, curTokenId, category);
    }
    function setCategories(uint256 tokenId, uint256[] memory categories) external override onlySoul(tokenId) {
        for(uint256 i=0; i<categories.length; i++){
            tokenIdToSBT[tokenId].categories.push(categories[i]);
        }

        emit CategoriesChanged(tokenIdToSBT[tokenId].soul, tokenId, categories);
    }
    function setPrimaryCategory(uint256 tokenId, uint256 primaryCategory) external override onlySoul(tokenId) {
        // we don't check if the primary category exists in the categories list to save gas, if it doesn't exist, user can add categories to the list later
        tokenIdToSBT[tokenId].category = primaryCategory;

        emit SoulChanged(tokenIdToSBT[tokenId].soul, tokenId, primaryCategory, tokenIdToSBT[tokenId].level, tokenIdToSBT[tokenId].collection, tokenIdToSBT[tokenId].collectionTokenId);
    }

    // Level up the soooul given signature from the core team
    // user can only level up the primary category
    // calldata is for external function's dynamic parameters
    function levelUp(uint256 tokenId, uint256 newLevel, NFTVoucher calldata voucher, bytes calldata signature) external override onlySoul(tokenId) {
        require(tokenIdToSBT[tokenId].category != 0, "Primary category has not been set.");

        // make sure that the tokenId is authorized (signed by the contract owner) to levelup
        _verify(voucher, signature, tokenId, newLevel);
        tokenIdToSBT[tokenId].level = newLevel;

        emit SoulChanged(tokenIdToSBT[tokenId].soul, tokenId, voucher.category, newLevel, tokenIdToSBT[tokenId].collection, tokenIdToSBT[tokenId].collectionTokenId);
    }

    // bind the soooul with specific NFT to upgrade its image
    // input 0 address to unbind
    function bind(uint256 tokenId, address collection, uint256 collectionTokenId) external override onlySoul(tokenId) {
        tokenIdToSBT[tokenId].collection = collection;
        tokenIdToSBT[tokenId].collectionTokenId = collectionTokenId;

        emit SoulChanged(tokenIdToSBT[tokenId].soul, tokenId, tokenIdToSBT[tokenId].category, tokenIdToSBT[tokenId].category, collection, collectionTokenId);
    }
    
    // only the soul owner can burn his/her own token
    function burn(uint256 tokenId) external onlySoul(tokenId) {
        _burn(tokenId);

        emit Destroyed(tokenIdToSBT[tokenId].soul, tokenId);
        soulToSBT[_msgSender()].tokenUri = '';
        tokenIdToSBT[tokenId].tokenUri = '';
        soulToSBT[_msgSender()].soul = address(0);
        tokenIdToSBT[tokenId].soul = address(0);
    }

    /// @dev Set new baseURI
    // function setBaseURI(string memory baseURI) external onlyOwner {
    //     baseTokenURI = baseURI;
    // }

    /// @dev override _baseURI()
    // function _baseURI() internal view override returns (string memory) {
    //     return baseTokenURI;
    // }

    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId();
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        // require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        // string memory baseURI = _baseURI();
        // return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
        
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        //require(_exists(tokenIdToSBT[tokenId]), "ERC721Metadata: URI query for nonexistent SB token");
        //require(_msgSender() == tokenIdToSBT[tokenId].soul || _msgSender() == owner(), "ERC721Metadata: only SB token owner or contract can query for URI");
        return tokenIdToSBT[tokenId].tokenUri;
    }

    // function updateTokenURI(string memory metadataURI) public {
    //     uint256 tokenId = soulToTokenId[_msgSender()];
    //     require(_exists(tokenId), "ERC721Metadata: URI update for nonexistent token");
    //     require(tokenIdToSBT[tokenId].soul == msg.sender, "only token owner can update URI");
    //     soulToSBT[_msgSender()].tokenUri = metadataURI;
    //     tokenIdToSBT[tokenId].tokenUri = metadataURI;
    // }

    function updateUserNFT(string memory metadataURI) public {
        uint256 currTokenId = soulToTokenId[_msgSender()];
        require(tokenIdToSBT[currTokenId].soul == msg.sender, "only token owner can update NFT");

        //burn current token
        _burn(currTokenId);
        emit Destroyed(tokenIdToSBT[currTokenId].soul, currTokenId);
        //soulToSBT[_msgSender()].tokenUri = '';
        tokenIdToSBT[currTokenId].tokenUri = '';
        //soulToSBT[_msgSender()].soul = address(0);
        tokenIdToSBT[currTokenId].soul = address(0);

        //mint new token for user
        uint256 category = 1;
        
        uint256[] memory categories = new uint256[](1);
        categories[0] = category;

        SBT memory sbt = SBT(msg.sender, category, categories, 0, address(0), 999999, metadataURI);
        soulToSBT[msg.sender].tokenUri = metadataURI; 
        uint256 nextTokenId = _nextTokenId();
        tokenIdToSBT[nextTokenId] = sbt;
        soulToTokenId[msg.sender] = nextTokenId;

        super._safeMint(msg.sender, 1);

        emit Minted(msg.sender, nextTokenId, category);
    }

    /// @dev Verify voucher
    function _verify(NFTVoucher calldata voucher, bytes calldata signature, uint256 tokenId, uint256 newLevel) public view {
        require(voucher.tokenId == tokenId, "Voucher's token ID is correct");
        require(voucher.newLevel == newLevel, "Voucher's new level is correct");
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("NFTVoucher(uint256 tokenId, uint256 newLevel)"),
                    tokenId,
                    newLevel
                )
            )
        );
        require(owner() == ECDSA.recover(digest, signature), "Signature invalid or unauthorized");
    }
}