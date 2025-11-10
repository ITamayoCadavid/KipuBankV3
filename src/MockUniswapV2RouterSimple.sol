// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint256 value) external returns (bool);
}

contract MockUniswapV2RouterSimple {
    address public owner;
    address tokenA;
    address tokenB;
    uint256 ratio;

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor(address _tokenA, address _tokenB, uint256 _ratio) {
        owner = msg.sender;
        tokenA = _tokenA;
        tokenB = _tokenB;
        ratio = _ratio;
    }

    /// @notice getAmountsOut con path de longitud 2 (tokenIn -> tokenOut)
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        uint[] memory resultado = new uint256[](2);
        resultado[0] = amountIn;
        resultado[1] = ratio * amountIn;
        return resultado;
    }

    /// @notice swapExactTokensForTokens simplificado
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        IERC20 tokenAdeployado = IERC20(tokenA);
        IERC20 tokenBdeployado = IERC20(tokenB);

        tokenAdeployado.transferFrom(msg.sender, address(this), amountIn);
        tokenBdeployado.transfer(to, ratio * amountIn);
    }
}
