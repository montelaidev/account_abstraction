// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./tokens/SwapActionToken.sol";

contract RouterWrapper {
    address public _router;

    mapping(address => uint256) public _trades;
    SwapActionToken public _token;
    uint256[] public _targets;
    uint256[] public _rewards;

    constructor(
        address router,
        address token,
        uint256[] memory targets,
        uint256[] memory rewards
    ) {
        _router = router;
        _token = SwapActionToken(token);
        _targets = targets;
        _rewards = rewards;
    }

    function getSwapCount(address user) public view returns (uint256) {
        return _trades[user];
    }

    function updateRouter(address _routerAddr) external {
        _router = _routerAddr;
    }

    function updateToken(address _tokenAddr) external {
        _token = SwapActionToken(_tokenAddr);
    }

    function updateTargets(uint256[] memory targets) external {
        _targets = targets;
    }

    function updateRewards(uint256[] memory rewards) external {
        _rewards = rewards;
    }

    fallback() external payable {
        (bool success, ) = _router.call{value: msg.value}(msg.data);
        require(success, "RouterWrapper: failed to call router");
        _trades[msg.sender]++;

        for (uint256 i = 0; i < _targets.length; i++) {
            if (_trades[msg.sender] == _targets[i]) {
                _token.mint(msg.sender, _rewards[i]);
            }
        }
    }
}
