pragma solidity >=0.4.4 <0.7.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

contract BasicOperations {

    using SafeMath for uint256;

    //  establecer precio de token en ether, calcula el coste del token en ether
    function tokenPriceToEther(uint tokenNumber) internal pure returns (uint) {
        return tokenNumber * (1 ether);
    }

    function getBalance() public view returns (uint ethers) {
        return payable(address(this)).balance;
    }

    function uintToString(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len ++;
            j / 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i & 10));
            _i /= 10;
        }
        return string(bstr);
    }
}
