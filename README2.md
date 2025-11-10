# KipuBankV3

## Descripción General
KipuBankV3 es una versión avanzada de KipuBankV2 que soporta:

- Depósitos de ETH y tokens ERC20.
- Depósitos de cualquier token soportado por Uniswap V2, que se intercambian automáticamente a USDC.
- Retiros de balances en USDC o ETH.
- Límite máximo global del banco (`bankCap`) y límite de retiro por transacción (`withdrawLimit`).

Se integra con un MockUniswapV2Router para simular swaps WETH → USDC en testnet.

---

## Contratos Desplegados

| Contrato | Dirección | Nota |
|----------|-----------|------|
| MockUSDC (ERC20) | `0x918cee9bfd71d73358516cef3e3610640dc40eb5` | Mock ERC20 USDC |
| MockWETH (ERC20) | `0xf9168336a59413893e03eb6732f9da9ee4298dc5` | Mock ERC20 WETH |
| MockUniswapV2Router | `0xc470c41a251523278c849cc36a40afe47ddc09c9` | Simula swaps WETH → USDC |
| KipuBankV3 | `0x98bb535322b28d6462163b78cc17ac3b1a15fcf7` | Verificado en Sourcify y Routescan |

Links de verificación:

- [Sourcify](https://repo.sourcify.dev/11155111/0x98bB535322B28d6462163b78cc17ac3b1a15fcf7/)
- [Routescan](https://testnet.routescan.io/address/0x98bB535322B28d6462163b78cc17ac3b1a15fcf7/contract/11155111/code)

> **Tip:** Las direcciones las obtienes de Remix luego del deploy de cada contrato, en la sección "Deployed Contracts".

---

## Funcionalidad

### Depósitos
- `depositETH()` → Deposita ETH directamente.
- `depositToken(address token, uint256 amount)` → Deposita ERC20:
  - Si es USDC, se almacena directamente.
  - Si es otro token (ej. WETH), se hace swap automático a USDC usando el router MockUniswapV2Router.

### Retiros
- `withdrawETH(uint256 amount)` → Retira ETH hasta el `withdrawLimit`.
- `withdrawToken(address token, uint256 amount)` → Retira USDC hasta el `withdrawLimit`.

### Consultas
- `getBalance(address user, address token)` → Retorna el balance del usuario en la moneda especificada.

---

## Instrucciones de Uso / Pruebas Simuladas

1. Conectar tu wallet (Metamask) a la testnet donde desplegaste los contratos.
2. Asegurarte de que tienes tokens mock (USDC y WETH) y aprobar el router si vas a depositar tokens distintos a USDC:

```solidity
IERC20(WETH).approve(MockUniswapV2RouterAddress, amount);
