pragma solidity =0.5.16;

import './interfaces/INordekV2Factory.sol';
import './NordekV2Pair.sol';
import './libraries/Roles.sol';

contract NordekV2Factory is INordekV2Factory {
    using Roles for Roles.Role;

    Roles.Role private _admin;

    address public feeTo;
    address public feeToSetter;
    bytes32 public constant INIT_CODE_HASH =
        keccak256(abi.encodePacked(type(NordekV2Pair).creationCode));

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    uint256 public swapFeeBP;

    address public feeReceiver;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    constructor(address _feeToSetter, address _feeReceiver) public {
        feeToSetter = _feeToSetter;
        feeReceiver = _feeReceiver;
        swapFeeBP = 100;
        _admin.add(msg.sender);
    }

    function addAdmin(address account) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        _admin.add(account);
    }

    function removeAdmin(address account) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        _admin.remove(account);
    }

    function lock(address pool) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        NordekV2Pair(pool).setLock(true);
    }

    function unlock(address pool) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        NordekV2Pair(pool).setLock(false);
    }

    function setFeeReceiver(address _feeReceiver) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        feeReceiver = _feeReceiver;
    }

    function setSwapFeeBP(uint256 value) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        swapFeeBP = value;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        require(tokenA != tokenB, 'NordekV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), 'NordekV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'NordekV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(NordekV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        INordekV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(_admin.has(msg.sender), 'NordekV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
