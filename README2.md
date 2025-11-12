# KipuBankV3

## Descripción General
KipuBankV3 es una versión avanzada de KipuBankV2 que soporta:

- Depósitos de ETH y tokens ERC20.
- Depósitos de cualquier token soportado por Uniswap V2, que se intercambian automáticamente a USDC.
- Retiros de balances en USDC o ETH.
- Límite máximo global del banco (`bankCap`) y límite de retiro por transacción (`withdrawLimit`).

Se integra con un MockUniswapV2Router para simular swaps WETH → USDC en testnet.

| Mejora                                             | Descripción                                           | Razón                                        |
| ---------------------------------------------------| ----------------------------------------------------- | -------------------------------------------- |
| Eliminado el doble swap (ETH ↔ USDC)               | Solo se permite swap ETH → USDC                       | Simplifica la lógica y reduce costos de gas  |
| Soporte para depósitos en ETH y ERC20              | Se admiten depósitos en ambas monedas                 | Aumenta la flexibilidad                      |
| Integración con MockUniswapV2Router                | Simula swaps ETH → USDC en testnet                    | Permite pruebas sin depender de Uniswap real |
| Límites configurables (`bankCap`, `withdrawLimit`) | Controla el total de fondos y los retiros por usuario | Mejora la seguridad                          |
| Registro de balances por usuario y token           | Permite trazabilidad y auditoría de saldos            | Facilita transparencia y control             |


---

## Contratos Desplegados

| Contrato | Dirección | Nota |
|----------|-----------|------|
| MockUSDC (ERC20) | `0x918cee9bfd71d73358516cef3e3610640dc40eb5` | Mock ERC20 USDC |
| MockWETH (ERC20) | `0xf9168336a59413893e03eb6732f9da9ee4298dc5` | Mock ERC20 WETH |
| MockUniswapV2Router | `0xc470c41a251523278c849cc36a40afe47ddc09c9` | Simula swaps WETH → USDC |
| KipuBankV3 | `0x98bb535322b28d6462163b78cc17ac3b1a15fcf7` | Verificado en Sourcify y Routescan |
---
| Contrato              | Dirección                                    | Descripción                  |
| --------------------- | -------------------------------------------- | ---------------------------- |
| `MockUSDC`            | `0x918cee9bfd71d73358516cef3e3610640dc40eb5` | Mock ERC20 de USDC           |
| `MockWETH`            | `0xf9168336a59413893e03eb6732f9da9ee4298dc5` | Mock ERC20 de WETH           |
| `MockUniswapV2Router` | `0xc470c41a251523278c849cc36a40afe47ddc09c9` | Simula swaps ETH → USDC      |
| `KipuBankV3`          | `0x98bb535322b28d6462163b78cc17ac3b1a15fcf7` | Contrato principal del banco |

##Verificacion
Links de verificación:

- [Sourcify](https://repo.sourcify.dev/11155111/0x98bB535322B28d6462163b78cc17ac3b1a15fcf7/)
- [Routescan](https://testnet.routescan.io/address/0x98bB535322B28d6462163b78cc17ac3b1a15fcf7/contract/11155111/code)
  
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
3. Depositar tokens:
4. Retirar tokens:
5. Consultar saldo:

```solidity
IERC20(WETH).approve(MockUniswapV2RouterAddress, amount);
depositToken(WETH, 100); // Se hace swap a USDC automáticamente y se actualiza tu balance
withdrawToken(USDC, 50); // Retira USDC hasta el límite permitido
getBalance(userAddress, USDC);

Ejemplo de Constructor del Contrato KipuBankV3

Al desplegar KipuBankV3, pega las direcciones de los mocks en el orden correcto:
constructor(
    address _router,
    address _WETH,
    address _USDC
)
Ejemplo
_router = 0xc470c41a251523278c849cc36a40afe47ddc09c9
_WETH   = 0xf9168336a59413893e03eb6732f9da9ee4298dc5
_USDC   = 0x918cee9bfd71d73358516cef3e3610640dc40eb5


Instrucciones de Interacción
🔹 Depósitos

Depositar ETH:depositETH()
Convierte automáticamente ETH a USDC mediante el router simulado.
Depositar tokens ERC20:IERC20(USDC).approve(KipuBankV3, amount);
depositToken(USDC, amount);

🔹 Retiros

Retirar ETH (hasta el límite):withdrawETH(amount);
Retirar USDC:withdrawToken(USDC, amount);

withdrawToken(USDC, amount);

🔹 Consultas

Consultar balance del usuario:
getBalance(userAddress, USDC);


##Decisiones de Diseño y Trade-offs

Se eliminó el swap USDC → ETH para reducir complejidad y fallos potenciales.

Se usa un MockUniswapV2Router para pruebas seguras en testnet, sin depender del protocolo real.

Los límites (bankCap y withdrawLimit) fueron añadidos para proteger la liquidez del contrato.

Se priorizó la claridad del código y seguridad sobre la optimización de gas, dado el propósito educativo.

