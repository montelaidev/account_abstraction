// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./tokens/SwapActionToken.sol";

contract RouterWrapper {
    address public _router;

    mapping(address => uint256) public _trades;
    SwapActionToken public _token;

    constructor(address router, address token) {
        _router = router;
        _token = SwapActionToken(token);
    }

    function updateRouter(address _routerAddr) external {
        _router = _routerAddr;
    }

    fallback() external payable {
        (bool success, ) = _router.call{value: msg.value}(msg.data);
        require(success, "RouterWrapper: failed to call router");
        _trades[msg.sender]++;

        if (_trades[msg.sender] == 1) {
            _token.mint(msg.sender, 1 ether);
        } else if (_trades[msg.sender] == 10) {
            _token.mint(msg.sender, 5 ether);
        } else if (_trades[msg.sender] == 30) {
            _token.mint(msg.sender, 10 ether);
        }
    }
}
