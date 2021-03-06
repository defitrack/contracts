import "./IMerkleDistributor.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MerkleDistributor is IMerkleDistributor,  Pausable, Ownable {

    using SafeERC20 for IERC20;


    address public immutable override token;
    bytes32 public immutable override merkleRoot;


    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(address token_, bytes32 merkleRoot_) public {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {


        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);

        uint256 distributionAmount = calculateMaxDistribution(account, amount);

        require(IERC20(token).transfer(account, distributionAmount), 'MerkleDistributor: Transfer failed.');

        emit Claimed(index, account, distributionAmount);
    }

    //Returns the amount a user would receive. Either 20% of the user's current balance or the distribution amount
    //whichever is the lowest.
    function calculateMaxDistribution(address account_, uint256 amount_) public view returns (uint256){
        IERC20 erc20 = IERC20(token);
        uint256 currentBalance = erc20.balanceOf(account_);
        uint256 bonusOnCurrentBalance = currentBalance / 5;
        if(bonusOnCurrentBalance >= amount_) {
            return amount_;
        } else {
            return bonusOnCurrentBalance;
        }
    }
}