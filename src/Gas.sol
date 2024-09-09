// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

contract GasContract {
    address public contractOwner;
    address[5] public administrators;

    mapping(address => uint256) public whitelist;
    mapping(address => uint256) public balances;
    mapping(address => ImportantStruct) public whiteListStruct;

    struct ImportantStruct {
        bool paymentStatus;
        uint256 amount;
    }

    event AddedToWhitelist(address userAddress, uint256 tier); // Cannot remove
    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);

    error InsufficientBalance(address);
    error InvalidCaller();
    error InvalidTier();

    modifier onlyAdminOrOwner() {
        require(
            msg.sender == contractOwner || checkForAdmin(msg.sender),
            InvalidCaller()
        );
        _;
    }

    modifier checkIfWhiteListed() {
        require(
            whitelist[msg.sender] > 0 && whitelist[msg.sender] < 4,
            InvalidTier()
        );
        _;
    }

    // constructor(address[] memory _admins, uint256 _totalSupply) {
    //     contractOwner = msg.sender;

    //     for (uint256 i = 0; i < administrators.length; i++) {
    //         if (_admins[i] != address(0)) {
    //             administrators[i] = _admins[i];
    //             if (_admins[i] == contractOwner) {
    //                 balances[contractOwner] = _totalSupply;
    //             }
    //         }
    //     }
    // }

    constructor(address[] memory _admins, uint256 _totalSupply) payable {
        contractOwner = msg.sender;

        assembly {
            let adminsSlot := administrators.slot
            for {
                let i := 0
            } lt(i, 5) {
                i := add(i, 1)
            } {
                let adminAddr := mload(add(_admins, mul(add(i, 1), 0x20)))
                if iszero(adminAddr) {
                    break
                }
                sstore(add(adminsSlot, i), adminAddr)

                if eq(adminAddr, caller()) {
                    mstore(0x00, adminAddr)
                    mstore(0x20, balances.slot)
                    let key := keccak256(0x00, 0x40)
                    sstore(key, _totalSupply)
                }
            }
        }
    }

    // function checkForAdmin(address _user) public view returns (bool admin_) {
    //     bool admin = false;
    //     for (uint256 i = 0; i < administrators.length; i++) {
    //         if (administrators[i] == _user) {
    //             admin = true;
    //         }
    //     }
    //     return admin;
    // }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        assembly {
            let adminsStartingSlot := administrators.slot
            for {
                let i := 0
            } lt(i, 5) {
                i := add(i, 1)
            } {
                if eq(sload(add(adminsStartingSlot, i)), _user) {
                    admin_ := 1
                }
            }
        }
    }

    function balanceOf(address _user) external view returns (uint256 balance_) {
        return balances[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        require(
            balances[msg.sender] >= _amount,
            InsufficientBalance(msg.sender)
        );

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);

        return true;
    }

    function addToWhitelist(
        address _userAddrs,
        uint256 _tier
    ) external onlyAdminOrOwner {
        require(_tier < 255, InvalidTier());

        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        }

        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) external checkIfWhiteListed {
        whiteListStruct[msg.sender] = ImportantStruct(true, _amount);

        require(
            balances[msg.sender] >= _amount,
            InsufficientBalance(msg.sender)
        );
        require(_amount > 3, "Amount to send have to be bigger than 3");

        uint256 whitelistAmount = whitelist[msg.sender];

        balances[msg.sender] =
            (balances[msg.sender] - _amount) +
            whitelistAmount;
        balances[_recipient] =
            (balances[_recipient] + _amount) -
            whitelistAmount;

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(
        address sender
    ) external view returns (bool, uint256) {
        return (
            whiteListStruct[sender].paymentStatus,
            whiteListStruct[sender].amount
        );
    }
}
