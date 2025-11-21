# Informe de Análisis de Amenazas — KipuBankV3

---

## 1) Resumen ¿Qué hace KipuBankV3?

KipuBankV3 es un contrato de custodia y conversión que permite depositar ETH (`depositETH`) y USDC directamente o depositar otros tokens y convertirlos por swap a USDC (`depositToken → swapTokenToUSDC`). Ademas, lleva contabilidad por usuario (`userETHBalances`, `userUSDCBalances`) y totales globales (`totalETHDeposits`, `totalUSDCDeposits`); permite retirar ETH (`withdrawETH`) y USDC (`withdrawUSDC`) con un `withdrawLimit` por transacción.  

KipuBankV3 usa un router externo `IUniswapV2Router` para swaps y depende de la dirección USDC. Sin embargo, tiene protecciones mínimas: hereda `Ownable` y `ReentrancyGuard`, y emite eventos para depósitos y retiros (pero no para swaps ni cambios).  

Este informe evalúa riesgos, define invariantes y propone correcciones y pruebas necesarias para preparar KipuBankV3 para una auditoría.

---

## 2) Evaluación de madurez

KipuBankV3 actualmente tiene baja madurez — el contrato compila pero no tiene pruebas que validen su comportamiento crítico.  

Los aspectos faltantes son:

- Cobertura / pruebas: 0% para `KipuBankV3.sol`. Por este motivo es urgente: unit tests para depósitos, retiros y swaps; invariantes automáticas; fuzzing.
- No hay operaciones de emergencia como por ejemplo `pausable`, `circuit breaker` ni mecanismos de recuperación.
- No hay comprobación de tokens o validación de tokens `fee-on-transfer` ni retorno de `transfer`/`transferFrom`.
- Control de permisos: `owner` existe (`Ownable`) pero no se detallan funciones administrativas que significarían menos riesgo; sin embargo `owner` podría seguir teniendo poderes indirectos (como por ejemplo la elección del router/USDC en constructor).

Por lo anterior KipuBankV3 no está listo para mainnet ni auditoría externa hasta cubrir pruebas, agregar mitigaciones y refinar los permisos.

---

## 3) Cobertura

Comando ejecutado en Foundry:

```bash
cd <KipuBankV3>
forge coverage
forge test --coverage
````

Resultado observado 
<img width="1007" height="435" alt="Informe de Cobertura en Foundry" src="https://github.com/user-attachments/assets/a65b7803-6783-44af-9c5b-4d7dca02cfe0" />


Total: 0%

**Conclusión de coverage:**
La cobertura del contrato principal `KipuBankV3.sol` es 0%: no existen pruebas unitarias que verifiquen su comportamiento. Por tanto, el proyecto requiere urgentemente la implementación de tests unitarios y de invariantes para validar depósitos, retiros, swaps y condiciones de borde antes de considerarlo maduro para auditoría o producción.

---

## 4) Vulnerabilidades / puntos críticos

### Vulnerabilidad A — Swap sin control de slippage (`swapTokenToUSDC`)

La llamada al router usa `amountOutMin = 0`, `router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);` lo cual afecta esta función `swapTokenToUSDC(address token, uint256 amount)` y significa que acepta cualquier cantidad de USDC como salida.

* **Criticidad:** CRÍTICA / ALTA
* **Impacto:** El contrato puede ser vulnerable a ataques MEV o de tipo sandwich, así como a manipulación de precios. Esto podría hacer que el swap termine devolviendo casi 0 USDC, lo que causaría una pérdida de fondos para el usuario que deposita y después, podría generar un riesgo serio de que se drenen más fondos del sistema.
* **Solución propuesta:** No aceptar `amountOutMin = 0`. Calcular `amountOutMin` desde frontend o desde contrato con oráculo/TWAP, o aceptar `minAmountOut` como parámetro elegido por el usuario.

**Ejemplo pasar `uint256 minAmountOut` desde depositToken:**

```solidity
// cambiar interfaz depositToken para recibir minAmountOut
function depositToken(address token, uint256 amount, uint256 minAmountOut) external nonReentrant { ... }

// en swapTokenToUSDC
uint[] memory amounts = router.swapExactTokensForTokens(
    amount,
    minAmountOut,
    path,
    address(this),
    block.timestamp
);
```

Se puede usar un oráculo off-chain (o on-chain TWAP) y aplicar un % de tolerancia.

---

### Vulnerabilidad B — Ausencia de mecanismo de emergencia / pausa (`withdrawETH` / `withdrawUSDC`)

Las funciones afectadas son `withdrawETH(uint256)` y `withdrawUSDC(uint256)`. Actualmente, el contrato no cuenta con un mecanismo `Pausable` ni con un `circuit-breaker`, por lo que, en caso de detectarse un exploit, no existe una forma de detener los retiros, aumentando el riesgo durante un incidente de seguridad.

* **Criticidad:** ALTA
* **Impacto:** Si ocurre un exploit o un error en la parte del swap, los atacantes o incluso usuarios podrían seguir retirando fondos sin control. Esto puede causar pérdidas económicas.
* **Solución propuesta:** Heredar `Pausable` de OZ y proteger funciones críticas:

```solidity
import "@openzeppelin/contracts/security/Pausable.sol";

contract KipuBankV3 is Ownable, ReentrancyGuard, Pausable { ... }

function withdrawETH(uint256 amount) external whenNotPaused nonReentrant { ... }

// owner functions to pause/resume
function pause() external onlyOwner { _pause(); }
function unpause() external onlyOwner { _unpause(); }
```

Opcionalmente tambien se puede añadir `emergencyWithdraw` (solo owner) con límite y eventos, y multi-sig para acciones críticas.

---

### Vulnerabilidad C — Aceptar tokens sin validación (tokens fee-on-transfer, rebase)

Las funciones `depositToken` y `swapTokenToUSDC` asumen que `transferFrom` y `transfer` siempre transfieren exactamente `amount`. No se revisa el valor de retorno ni se valida si el token aplica tarifas (`fee-on-transfer`). Tampoco se comprueba la cantidad real recibida, lo que podría causar inconsistencias.

* **Criticidad:** ALTA / MEDIO depende del token
* **Impacto:** Los balances internos pueden quedar desincronizados. El usuario podría pensar que depositó X, pero el contrato recibe X menos tarifa, haciendo que `userUSDCBalances` muestre más de lo que realmente tiene lo cual podria llevar a insolvencia o pérdidas.
* **Solución técnica propuesta:** Usar `SafeERC20` y comprobar retornos.

```solidity
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;

IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

uint256 before = IERC20(token).balanceOf(address(this));
IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
uint256 after = IERC20(token).balanceOf(address(this));
uint256 actualReceived = after - before;

// En caso de fee-on-transfer, rechazar token o soportarlo explícitamente y reflejar actualReceived al usuario
```

---

### Vulnerabilidad D — Uso de `msg.sender.call{value:}` sin límites y posible fallback issues (retiro ETH)

La función `withdrawETH(uint256 amount)` usa `(bool sent, ) = msg.sender.call{value: amount}(""); require(sent, "Fallo transferencia ETH")` para enviar ETH. Puede interactuar con contratos que tengan código en `fallback` o `receive`.

* **Criticidad:** MEDIO
* **Impacto:** Contratos maliciosos podrían forzar reverts y causar bloqueos. Aunque `ReentrancyGuard` ayuda, es mejor evitar lógica después del call y emitir eventos correctamente.
* **Solución propuesta:**

```solidity
// Mantener checks-effects-interactions: balances actualizados antes del call
// Considerar usar Address.sendValue(payable(msg.sender), amount) (OZ) para seguridad
// Registrar evento WithdrawETH (ya existe)
```

---

### Vulnerabilidades E — Contadores manuales sin reconciliación (`totalETHDeposits` / `totalUSDCDeposits`)

Los contadores se incrementan/decrementan manualmente. Un revert parcial, ruta alternativa o token con fee puede desincronizarlos.

* **Criticidad:** MEDIO
* **Impacto:** La suma de `user*Balances` podría quedar fuera de sync con `total*Deposits`, rompiendo la invariante contable → insolvencia o errores en limit checks (`bankCap`).
* **Solución propuesta:**

```solidity
// Función interna reconcileUSDC() o calcular totals a partir de address(this).balance y IERC20(USDC).balanceOf(address(this)) para verificación periódica
// Incluir tests que provoquen diferencias intencionales
```

---

## 5) Invariantes

* **Invariante 1 — Suma de balances == totales internos**
  `sum_over_users(userETHBalances[user]) == totalETHDeposits` y análogo para USDC.
  Garantiza contabilidad correcta.
  Validación: tests de invariantes con Foundry / Echidna.

```solidity
function invariant_total_eth_matches_user_sum() public view {
    uint256 sum = 0;
    for each user in users: sum += bank.userETHBalances(user);
    assertEq(sum, bank.totalETHDeposits());
}
```

* **Invariante 2 — Totales ≤ bankCap**
  `totalETHDeposits <= bankCap` y `totalUSDCDeposits <= bankCap`.
  Evita over-capacity y respeta modelo económico.

* **Invariante 3 — No existen balances negativos; cada retiro limitado por user balance**
  `userETHBalances[user] >= 0` y `userUSDCBalances[user] >= 0`. Withdraw nunca permite `userBalance < 0`.

* **Invariante 4 — Tokens recibidos por swap ≧ amountOutMin**
  `usdcReceived >= amountOutMin` en cada swap. Validación: mockear router y validar amounts[1] >= minOut.

---

## 6) Recomendaciones Cómo validar invariantes en Foundry

* Implementar tests tipo property/invariant con `forge-std StdInvariant` o usar Echidna.
* Ejemplo: crear `KipuBankInvariant.t.sol` que extienda `StdInvariant` y registre invariantes.
* Ejecutar `forge test` y `forge coverage`.
* Fuzz tests para deposit/withdraw con valores aleatorios.
* Verificar cobertura de rutas críticas (depositToken con swap, failed swaps, withdraw edge cases).

---

## 7) Próximos pasos necesarios para alcanzar la madurez del protocolo y completar la preparación para una auditoría

*Crear una buena suite de tests unitarios que cubra al menos las partes más importantes del contrato (≥80% de la ruta crítica).

*Configurar tests automáticos de invariantes usando Foundry o Echidna para asegurarnos de que las reglas siempre se cumplan.

*Implementar control de slippage y usar oráculos o parámetros para definir amountOutMin en los swaps.

*Añadir mecanismos de pausa y procedimientos de emergencia, y documentar cómo usarlos.

*Usar SafeERC20 y reconciliar balances.

*Hacer revisión manual y pruebas en testnet, tanto con un router simulado como con Uniswap V2 real en testnet, para asegurarnos de que todo funciona como se espera.

##  Recomendaciones

**A) Protección en swaps**

```solidity
function swapTokenToUSDC(address token, uint256 amount, uint256 minAmountOut) internal returns (uint256) {
    using SafeERC20 for IERC20;
    IERC20(token).safeApprove(address(router), amount);
    address;
    path[0] = token; path[1] = USDC;
    uint[] memory amounts = router.swapExactTokensForTokens(amount, minAmountOut, path, address(this), block.timestamp);
    require(amounts[1] >= minAmountOut, "Slippage too high");
    return amounts[1];
}
```

* Exponer `minAmountOut` en `depositToken` o calcularlo con oráculo.

**B) Pausable / Emergency**

* Heredar `Pausable` y añadir `whenNotPaused`.
* Agregar `pause()` / `unpause()` `onlyOwner`.

**C) SafeERC20 y comprobación de cantidades**

* Reemplazar `IERC20(...).transferFrom(...)` por `safeTransferFrom`.
* Usar balance diffs para detectar fees.

**D) Mejorar eventos y logging**

* Emitir evento `SwapExecuted(...)` con `amountIn` y `amountOut`.
* Emitir eventos administrativos (`router changed`, `owner changed`, `pause/unpause`).

**Tests a implementar**

1. `depositETH` success y revert cuando supera `bankCap`.
2. `depositToken(USDC)` success y balances correctos.
3. `depositToken(non-USDC)` usando mocked router (happy path + slippage revert).
4. `withdrawETH` y `withdrawUSDC` success/fail en insuficiente balance.
5. Invariant tests: sum(user balances) == totals.
6. Fuzz tests en deposit/withdraw (Foundry fuzz).


---



