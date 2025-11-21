Informe de Análisis de Amenazas — KipuBankV3

________________________________________
1) Resumen ¿Qué hace KipuBankV3?
KipuBankV3 es un contrato de custodia y conversión que permite depositar ETH (depositETH) y USDC directamente o depositar otros tokens y convertirlos por swap a USDC (depositToken → swapTokenToUSDC). Ademas, lleva contabilidad por usuario (userETHBalances, userUSDCBalances) y totales globales (totalETHDeposits, totalUSDCDeposits); permite retirar ETH (withdrawETH) y USDC (withdrawUSDC) con un withdrawLimit por transacción. KipuBankV3 usa un router externo IUniswapV2Router para swaps y depende de la dirección USDC. Sin embargo, tiene protecciones mínimas: hereda Ownable y ReentrancyGuard, y emite eventos para depósitos y retiros (pero no para swaps ni cambios).
Este informe evalúa riesgos, define invariantes y propone correcciones y pruebas necesarias para preparar KipuBankV3 para una auditoría/mainnet.
________________________________________
2) Evaluación de madurez 
KipuBankV3 atuelmente tiene baja madurez — el contrato compila pero no tiene pruebas que validen su comportamiento crítico.
Los aspectos faltantes son:
•	Cobertura / pruebas: 0% para KipuBankV3.sol (ver sección Coverage).Por este motivo es urgente: unit tests para depositos, retiros y swaps; invariantes automáticas; fuzzing.
•	No hay operaciones de emergencia como por ejemplo pausable, circuit breaker ni mecanismos de recuperación.
•	No hay comprobación de tokens o validación de tokens fee-on-transfer ni retorno de transfer/transferFrom.
•	Control de permisos: owner existe (Ownable) pero no se detallan funciones administrativas que significarian menos riesgo, sin embargo owner podría seguir teniendo poderes indirectos (como por ejemplo la elección del router/USDC en constructor).
Conclusión: KipuBankV3 no esta listo para mainnet ni auditoría externa hasta cubrir pruebas, agregar mitigaciones y refinar los permisos.
________________________________________
3) Cobertura 
Comando ejecutado en Foundry (ejemplos válidos):

cd <KipuBankV3>
forge coverage
forge test --coverage
Resultado observado (ejemplo, obtenido en este repo):
| src/Counter.sol      | 100.00% (4/4) | ...
| src/KipuBankV3.sol   |   0.00% (0/51) | ...
Total: 6.67% ...
Conclusión de coverage:
La cobertura del contrato principal KipuBankV3.sol es 0%: no existen pruebas unitarias que verifiquen su comportamiento. Por tanto, el proyecto requiere urgentemente la implementación de tests unitarios y de invariantes para validar depósitos, retiros, swaps y condiciones de borde antes de considerarlo maduro para auditoría o producción.

________________________________________
4) Vulnerabilidades / puntos críticos
   
Vulnerabilidad A — Swap sin control de slippage (swapTokenToUSDC)

La Llamada al router usa amountOutMin = 0, router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp); lo cual afecta esta funcion swapTokenToUSDC(address token, uint256 amount) y significa que acepta cualquier cantidad de USDC como salida.
•	Criticidad: CRÍTICA / ALTA
•	El impacto de este problema es que el contrato puede ser vulnerable a ataques MEV o de tipo sandwich, así como a manipulación de precios. Esto podría hacer que el swap termine devolviendo casi 0 USDC, lo que causaría una pérdida directa de fondos para el usuario que deposita y, después, podría generar un riesgo serio de que se drenen más fondos del sistema.
•	La solucion propuesta implica No aceptar amountOutMin = 0. Calcular amountOutMin desde frontend o desde contrato con oráculo/TWAP, o aceptar minAmountOut como parámetro elegido por el usuario.
o	Ejemplo (parche mínimo, pasar uint256 minAmountOut desde depositToken):
o	// cambiar interfaz depositToken para recibir minAmountOut
o	function depositToken(address token, uint256 amount, uint256 minAmountOut) external nonReentrant { ... }
o	
o	// en swapTokenToUSDC
o	uint[] memory amounts = router.swapExactTokensForTokens(
o	    amount,
o	    minAmountOut,
o	    path,
o	    address(this),
o	    block.timestamp
o	);
Se pued validar usar un oráculo off-chain (o on-chain TWAP) para derivar expectedOut y aplicar un % de tolerancia (ej. 95% de expectedOut).
________________________________________
Vulnerabilidad B — Ausencia de mecanismo de emergencia / pausa (withdrawETH / withdrawUSDC)

Las funciones afectadas son withdrawETH(uint256) y withdrawUSDC(uint256). Actualmente, el contrato no cuenta con un mecanismo Pausable ni con un circuit-breaker, por lo que, en caso de detectarse un exploit, no existe una forma de detener los retiros lo que aumenta el riesgo durante un incidente de seguridad.
•	Criticidad: ALTA
•	El impacto es que, si ocurre un exploit o un error en la parte del swap, los atacantes o incluso usuarios podrían seguir retirando fondos sin control. Esto puede causar pérdidas económicas.
•	La solución propuesta es heredar Pausable de OZ y proteger funciones críticas:
o	import "@openzeppelin/contracts/security/Pausable.sol";
o	contract KipuBankV3 is Ownable, ReentrancyGuard, Pausable { ... }
o	
o	function withdrawETH(uint256 amount) external whenNotPaused nonReentrant { ... }
o	
o	// owner functions to pause/resume
o	function pause() external onlyOwner { _pause(); }
o	function unpause() external onlyOwner { _unpause(); }
o	Opcional: añadir emergencyWithdraw (solo owner) con límite y eventos, y multi-sig para acciones críticas.
________________________________________
Vulnerabilidad C — Aceptar tokens sin validación (tokens fee-on-transfer, rebase, etc.)

Las funciones depositToken y swapTokenToUSDC tienen un problema porque el contrato asume que las llamadas a transferFrom y transfer siempre transfieren exactamente la cantidad indicada en amount. Sin embargo, no se revisa el valor de retorno de estas funciones ni se valida si el token aplica tarifas (fee-on-transfer). Tampoco se comprueba cuánta cantidad se recibió realmente, lo que podría causar inconsistencias o errores en el contrato.
•	Criticidad: ALTA / MEDIO depende del token
El impacto es que los balances internos pueden quedar desincronizados, porque el usuario podría pensar que depositó una cantidad X, pero el contrato en realidad recibe X menos la tarifa del token. Esto hace que userUSDCBalances muestre más de lo que el contrato realmente tiene, lo que puede llevar a insolvencia o a pérdidas de fondos.
•	Solución técnica propuesta
o	Usar SafeERC20 de OpenZeppelin y comprobar retornos:
o	import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
o	using SafeERC20 for IERC20;
o	IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
o	Después del transferFrom, comprobar saldo antes/después para calcular actualReceived:
o	uint256 before = IERC20(token).balanceOf(address(this));
o	IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
o	uint256 after = IERC20(token).balanceOf(address(this));
o	uint256 actualReceived = after - before;
o	En caso de fee-on-transfer, rechazar el token o soportarlo explícitamente y reflejar actualReceived al usuario.
________________________________________
Vulnerabilidad D — Uso de msg.sender.call{value:} sin límites y posible fallback issues (retiro ETH)

La función withdrawETH(uint256 amount) usa el patrón (bool sent, ) = msg.sender.call{value: amount}("")  con require(sent, "Fallo transferencia ETH") para enviar ETH. El problema es que este método puede interactuar con contratos que tengan código en fallback o receive, lo que podría generar comportamientos inesperados. Aunque el contrato usa nonReentrant, es buena práctica emplear métodos más seguros, como sendValue, o un enfoque de “pull over push” con verificaciones para reducir riesgos.
•	Criticidad: MEDIO
El impacto es que, al interactuar con contratos maliciosos, estos podrían forzar reverts y causar bloqueos si la situación no se maneja correctamente. Aunque ReentrancyGuard ayuda a reducir riesgos, lo más seguro es evitar ejecutar lógica después del call y asegurarse de emitir los eventos apropiados para mantener el flujo del contrato claro y protegido.
•	Solución propuesta:
o	Mantener checks-effects-interactions: ya se actualizan balances antes de la call (bien).
o	Considerar usar Address.sendValue(payable(msg.sender), amount) (OZ) para seguridad y claridad.
o	Registrar evento WithdrawETH (ya existe).
________________________________________
Vulnerabilidades E — Contadores manuales sin reconciliación (totalETHDeposits / totalUSDCDeposits)

Las funciones de depósito y retiro pueden tener problemas porque los valores de totalETHDeposits y totalUSDCDeposits se actualizan manualmente. Si en algún punto ocurre un revert parcial, una ruta alternativa o un token aplica tarifas, esos contadores pueden no actualizarse correctamente. Esto puede dejar los totales inconsistentes y causar errores en el seguimiento real de los fondos del contrato.
•	Criticidad: MEDIO
El impacto es que la suma de user*Balances podría quedar desincronizada con total*Deposits, rompiendo la invariante contable del contrato. Esto puede generar insolvencia o causar errores al verificar límites, como bankCap, poniendo en riesgo la seguridad y el funcionamiento.
•	Solución propuesta:
o	Añadir funciones interna reconcileUSDC() o calcular totals a partir de address(this).balance y IERC20(USDC).balanceOf(address(this)) para verificación periódica.
o	En tests, incluir casos que intencionalmente provoquen diferencias para detectar errores.
________________________________________
5) Invariantes
Qué es una invariante: propiedad que siempre debe cumplirse, independientemente del orden de llamadas ni de ataques.
Invariante 1 — Suma de balances == totales internos
Formal: sum_over_users(userETHBalances[user]) == totalETHDeposits y análogo para USDC.
Por qué: garantiza contabilidad correcta.
Cómo validar: tests de invariantes con Foundry / Echidna:
// pseudocódigo de invariants test (Foundry)
function invariant_total_eth_matches_user_sum() public view {
    uint256 sum = 0;
    for each user in users: sum += bank.userETHBalances(user);
    assertEq(sum, bank.totalETHDeposits());
}

Invariante 2 — Totales ≤ bankCap
Formal: totalETHDeposits <= bankCap y totalUSDCDeposits <= bankCap.
Por qué: evita over-capacity y respeta el modelo económico.
Cómo validar: invariant test que intente depositar más y verifique el require.

Invariante 3 — No existen balances negativos; cada retiro está limitado por user balance
Formal: userETHBalances[user] >= 0 y userUSDCBalances[user] >= 0 y withdraw nunca permite userBalance < 0.
Cómo validar: proof-style property tests + unit tests en retiros.
(Extra) 

Invariante 4 — Tokens recibidos por swap ≧ amountOutMin
Formal: usdcReceived >= amountOutMin en cada swap.
Cómo validar: en tests mockear router y validar que swapTokenToUSDC devuelve amounts[1] >= minOut.
________________________________________
6) Cómo validar invariantes en Foundry (pasos concretos)
•	Implementar tests tipo property/invariant con forge-std StdInvariant o usar Echidna.
•	Ejemplo con Foundry / Forge: crear KipuBankInvariant.t.sol que extienda StdInvariant y registre invariantes descritas arriba; ejecutar forge test y forge coverage.
•	Ejecutar fuzz tests para deposit/withdraw con valores aleatorios.
•	Ejecutar forge test + forge coverage y comprobar que los tests cubren rutas críticas (depositToken with swap, failed swaps, withdraw edge cases).
________________________________________
7) Recomendaciones prácticas y parches

A) Protección en swaps (parche mínimo)
•	Cambiar swapTokenToUSDC para aceptar minAmountOut y usar SafeERC20:
function swapTokenToUSDC(address token, uint256 amount, uint256 minAmountOut) internal returns (uint256) {
    using SafeERC20 for IERC20;
    IERC20(token).safeApprove(address(router), amount);
    address;
    path[0] = token; path[1] = USDC;
    uint[] memory amounts = router.swapExactTokensForTokens(amount, minAmountOut, path, address(this), block.timestamp);
    require(amounts[1] >= minAmountOut, "Slippage too high");
    return amounts[1];
}
•	Exponer minAmountOut en depositToken (o calcularlo con oráculo).

B) Pausable / Emergency
•	Heredar Pausable y añadir whenNotPaused donde corresponde; agregar pause()/unpause() onlyOwner.

C) SafeERC20 y comprobación de cantidades
•	Reemplazar IERC20(...).transferFrom(...) por safeTransferFrom y usar balance diffs para detectar fees.

D) Mejorar eventos y logging
•	Emitir evento SwapExecuted(...) con amountIn y amountOut.
•	Emitir eventos administrativos (router changed, owner changed, pause/unpause).

E) Tests mínimos a implementar (prioridad)
1.	depositETH success and revert when surpassing bankCap.
2.	depositToken(USDC) success and correct userUSDCBalances.
3.	depositToken(non-USDC) using mocked router returns expected USDC (happy path + slippage revert).
4.	withdrawETH and withdrawUSDC success / fail on insufficient balance.
5.	Invariant tests: sum(user balances) == totals.
6.	Fuzz tests on deposit/withdraw amounts (Foundry fuzz).
________________________________________
8) Checklist mínimo antes de pedir auditoría externa
•	 Suite de tests unitarios (≥80% ruta crítica)
•	 Tests de invariantes automáticos (Foundry/Echidna)
•	 Slippage control y oráculos/parametrización de amountOutMin
•	 Pausable / Emergency procedures y documentación de flujo de emergencia
•	 SafeERC20 + balance reconciliation (para tokens con fees)
•	 Documentación: README con comandos para reproducir tests y coverage, diagramas y supuestos (USDC address, router)
•	 Revisión manual y pruebas de integración en testnet (con router mock y con Uniswap V2 en testnet)
________________________________________
9) Conclusión y siguientes 
