# 🏦 KipuBankV3

## Descripción General

**KipuBankV3** es la evolución avanzada del contrato **KipuBankV2**, diseñada como una aplicación DeFi completa y segura.  
Integra soporte multi-token, control de límites, conversión automática a USDC mediante Uniswap V2, y buenas prácticas de seguridad y arquitectura.

---

## Funcionalidades Principales

### Depósitos
- **ETH nativo:** mediante `depositETH()`
- **Tokens ERC20 (como USDC o WETH):** mediante `depositToken(address token, uint256 amount)`
- Si el token depositado **no es USDC**, el contrato lo intercambia automáticamente por USDC usando el router Uniswap V2 (en este caso, un **Mock Router** para testnet).

### Retiros
- `withdrawETH(uint256 amount)` → Retira ETH hasta el límite permitido (`withdrawLimit`).
- `withdrawToken(address token, uint256 amount)` → Retira USDC hasta el límite permitido.

### Consultas
- `getBalance(address user, address token)` → Retorna el balance del usuario en la moneda especificada.
- El contrato mantiene la contabilidad separada por token y valida que los depósitos no superen el **bankCap** global.

---

## Variables Clave

| Variable | Descripción |
|-----------|--------------|
| `bankCap` | Límite máximo del banco (en USDC). |
| `withdrawLimit` | Límite de retiro por transacción. |
| `balances` | Mapping anidado para almacenar los saldos de cada usuario por token. |
| `router` | Dirección del contrato MockUniswapV2Router. |
| `WETH` / `USDC` | Direcciones de los tokens mock. |

---

## Despliegue de Contratos Mock

### Desplegar MockUSDC.sol
Contrato ERC20 simulado para representar USDC.

- **Ejemplo de dirección:**  
  `0x918cee9bfd71d73358516cef3e3610640dc40eb5`

### Desplegar MockWETH.sol
Contrato ERC20 simulado para representar WETH.

- **Ejemplo de dirección:**  
  `0xf9168336a59413893e03eb6732f9da9ee4298dc5`

---

## Desplegar MockUniswapV2Router

Este contrato simula el comportamiento de Uniswap para pruebas.  
Recibe las direcciones de WETH y USDC mock como parámetros del constructor:

```solidity
constructor(address _WETH, address _USDC) {
    WETH = _WETH;
    USDC = _USDC;
}
````

### Parámetros de ejemplo al desplegar:

```
_WETH = 0xf9168336a59413893e03eb6732f9da9ee4298dc5
_USDC = 0x918cee9bfd71d73358516cef3e3610640dc40eb5
```

* **Ejemplo de dirección desplegada:**
  `0xc470c41a251523278c849cc36a40afe47ddc09c9`

---

## Desplegar KipuBankV3

Finalmente, despliega el contrato principal **KipuBankV3**, indicando en el constructor:

```
_router = dirección del MockUniswapV2Router
_WETH = dirección del MockWETH
_USDC = dirección del MockUSDC
```

* **Ejemplo:**
  `_router = 0xc470c41a251523278c849cc36a40afe47ddc09c9`
  `_WETH = 0xf9168336a59413893e03eb6732f9da9ee4298dc5`
  `_USDC = 0x918cee9bfd71d73358516cef3e3610640dc40eb5`

* **Dirección desplegada:**
  `0x98bb535322b28d6462163b78cc17ac3b1a15fcf7`

Verificado en **Sourcify** y **Routescan**.

---

## Orden de Despliegue Resumido

| Paso | Contrato            | Parámetros del Constructor | Resultado            |
| ---- | ------------------- | -------------------------- | -------------------- |
| 1️⃣  | MockUSDC            | —                          | Token mock USDC      |
| 2️⃣  | MockWETH            | —                          | Token mock WETH      |
| 3️⃣  | MockUniswapV2Router | (WETH, USDC)               | Simulador de Uniswap |
| 4️⃣  | KipuBankV3          | (router, WETH, USDC)       | Contrato principal   |

---

## Instrucciones de Uso / Pruebas Simuladas

1. Conecta tu **wallet (Metamask)** a la testnet ( **Sepolia**).
2. Asegúrate de tener tokens mock (USDC y WETH).
3. Aprueba el router antes de depositar tokens distintos a USDC:

```solidity
IERC20(WETH).approve(MockUniswapV2RouterAddress, amount);
```

4. Deposita tokens:

```solidity
depositToken(WETH, 100); // Se hace swap a USDC automáticamente
```

5. Retira tokens:

```solidity
withdrawToken(USDC, 50);
```

6. Consulta saldo:

```solidity
getBalance(userAddress, USDC);
```

---

## Mejoras Implementadas y Justificación

| Mejora                                                | Motivo                                                                  |
| ----------------------------------------------------- | ----------------------------------------------------------------------- |
| **Soporte multi-token**                               | Permite depósitos tanto en ETH como en cualquier token ERC20 soportado. |
| **Integración con Uniswap V2**                        | Automatiza la conversión de tokens a USDC.                              |
| **Control de límites (`bankCap` y `withdrawLimit`)**  | Evita sobrepasar los fondos máximos o retiros abusivos.                 |
| **Contabilidad separada por token**                   | Mejora la transparencia y precisión del balance.                        |
| **Seguridad reforzada (Checks-Effects-Interactions)** | Reduce riesgo de reentradas y errores de transferencia.                 |
| **Uso de `constant`, `immutable` y eventos**          | Optimiza consumo de gas y facilita auditoría.                           |
| **Documentación profesional**                         | Cumple con estándares de proyectos open-source.                         |

---

## Decisiones de Diseño y Trade-offs

* Se usa un **Mock Router** para testnet por simplicidad, evitando dependencias reales con Uniswap.
* Se priorizó **claridad y seguridad** sobre optimización extrema de gas.
* El swap ETH → USDC fue implementado, pero el sentido inverso (USDC → ETH) se omitió deliberadamente para reducir complejidad y riesgos.
* Se utiliza **mapeo anidado** `balances[user][token]` para permitir futura expansión a otros activos ERC20.

---

## 🧾 Contratos Desplegados

| Contrato            | Dirección                                  | Nota               |
| ------------------- | ------------------------------------------ | ------------------ |
| MockUSDC (ERC20)    | 0x918cee9bfd71d73358516cef3e3610640dc40eb5 | Token USDC mock    |
| MockWETH (ERC20)    | 0xf9168336a59413893e03eb6732f9da9ee4298dc5 | Token WETH mock    |
| MockUniswapV2Router | 0xc470c41a251523278c849cc36a40afe47ddc09c9 | Simulador de swaps |
| KipuBankV3          | 0x98bb535322b28d6462163b78cc17ac3b1a15fcf7 | Contrato principal |

---

## Verificación

* [Sourcify](https://repo.sourcify.dev/11155111/0x98bB535322B28d6462163b78cc17ac3b1a15fcf7)
* [Routescan](https://testnet.routescan.io/address/0x98bB535322B28d6462163b78cc17ac3b1a15fcf7/contract/11155111/code)

---

## Licencia

Este proyecto es de carácter educativo y se publica bajo la licencia **MIT**.

---


