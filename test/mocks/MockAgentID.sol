// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal stand-in for the SPACE ID Agent ID registry, used only in tests.
///         Reproduces the two behaviours RollCall depends on:
///           - balanceOf(address) > 0  <=>  the address holds an Agent ID
///           - tokenId = uint256(keccak256(bytes(name))), ownerOf(tokenId) = holder
///         In tests this contract's code is etched onto the real registry address
///         (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F) so RollCall talks to the
///         exact address it will use on mainnet.
contract MockAgentID {
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _owners;

    function mint(address to, string memory name) external returns (uint256 tokenId) {
        tokenId = uint256(keccak256(bytes(name)));
        require(_owners[tokenId] == address(0), "name taken");
        _owners[tokenId] = to;
        _balances[to] += 1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "nonexistent token");
        return owner;
    }
}
