
# ✅ **Informe Técnico – Vulnerabilidades Encontradas en KipuBankV3**

Este informe presenta las vulnerabilidades identificadas durante la revisión del contrato inteligente **KipuBankV3**. 

---

# **1. Swap sin control de deslizamiento ni verificación de precio (swapTokenToUSDC)**

**Criticidad: ALTA**

### ❗ Problema

La función **swapTokenToUSDC()** ejecuta:

```solidity
router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);
```

Usar un `amountOutMin = 0` es extremadamente peligroso porque **acepta cualquier cantidad de USDC**, incluso cantidades ínfimas, lo que permite:

* Pérdida de fondos del usuario por deslizamiento extremo.
* Ataques MEV o sandwich, donde bots manipulan el precio para que el usuario reciba casi 0 USDC.
* Riesgo de ejecución a un precio desfavorable durante congestión.

### Solución recomendada

* Calcular un `amountOutMin` razonable desde frontend o contrato usando oráculos o estimaciones previas:

```solidity
uint256 minOut = expectedOut * 95 / 100;  // tolerancia del 5%
```

* O permitir que el usuario pase su `minAmount` como parámetro.

---

# **2. Los retiros no implementan un mecanismo de pausa de emergencia (withdrawETH / withdrawUSDC)**

**Criticidad: MEDIA**

### ❗ Problema

Las funciones **withdrawETH()** y **withdrawUSDC()** permiten retiros normalmente, pero el contrato **no tiene un mecanismo de emergencia** (como pause/unpause).
Si ocurre:

* Exploit del router
* Error en cálculos internos
* Manipulación de balances

el dueño **no tiene forma de detener retiros** antes de que los fondos se agoten.

Esto es crítico en un “banco” DeFi, donde los retiros son el camino principal de salida de fondos.

### Solución recomendada

* Heredar de **Pausable** de OpenZeppelin:

```solidity
function withdrawETH(uint256 amount) external whenNotPaused nonReentrant { ... }
```

* Permitir al owner activar `pause()` si detecta actividad sospechosa.

---

# **3. Falta de validaciones adicionales en depositETH() y depositToken()**

**Criticidad: BAJA **

### ❗ Problema

Aunque se comprueba `amount > 0`, faltan validaciones adicionales:

* En **depositETH()**, se permite depositar cantidades muy pequeñas (por ejemplo 1 wei), lo cual puede congestionar el almacenamiento y generar costos innecesarios para otros usuarios.
* En **depositToken()**, no se verifica:

  * si el token tiene 0 decimales
  * si el token tiene tasas o fees
  * si el token puede revertir transferencias parcialmente (tokens deflacionarios)

Esto puede causar que el contrato calcule balances incorrectos.

### Solución recomendada

* Establecer un depósito mínimo razonable:

```solidity
require(msg.value >= 0.001 ether, "Deposito minimo 0.001 ETH");
```

* Verificar que el token no reduzca el monto enviado (detectando diferencias entre `amount` y lo recibido).

---

# **4. Falta de eventos críticos en varias operaciones**

**Criticidad: MEDIA**

El contrato sí tiene eventos para depósitos y retiros, pero **no tiene eventos para swaps**, que son las operaciones más sensibles, ni eventos administrativos como:

* Cambios de limites
* Cambios del router
* Cambios del owner

Esto afecta trazabilidad, auditoría y debugging.

### Solución recomendada

Agregar eventos como:

```solidity
event SwapExecuted(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);
event OwnerChanged(address previousOwner, address newOwner);
```

Y emitirlo dentro de `swapTokenToUSDC`.

---

# **Conclusión sobre la Cobertura** 

Actualmente, el contrato principal KipuBankV3.sol tiene 0% de cobertura, ya que no existen pruebas unitarias que validen su comportamiento.

Esto confirma la necesidad de:

Crear pruebas unitarias para todas las funciones principales.

Aumentar la cobertura para mejorar la confiabilidad del contrato.

Verificar rutas críticas como depósitos, retiros, swaps y seguridad.

Sin pruebas, el proyecto no puede considerarse seguro.
Por ello, el siguiente paso es escribir tests para aumentar la cobertura y validar el funcionamiento del sistema.

<img width="1007" height="435" alt="image" src="https://github.com/user-attachments/assets/5f1a88ae-6afe-4c7b-be0b-25e3d4423808" />

# **Conclusión General**

Aunque el contrato cumple bien su función básica, todavía presenta riesgos importantes relacionados con:

* Interacciones con routers externos (alto riesgo inherente)
* Ausencia de mecanismos de seguridad de emergencia
* Falta de controles estrictos en swaps
* Inconsistencias en validación y trazabilidad

Corregir estas vulnerabilidades mejorará significativamente la seguridad, especialmente considerando que el contrato maneja depósitos de usuarios y realiza intercambios de tokens.

