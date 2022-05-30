# Subasta_Solidity
Una subasta a ciegas usando un contrato inteligente echo en solidity
Este contrato usa un **constructor el cual requiere:**
- Fecha de finalizacion de la subasta
- Fecha de revelacion de todas las ofertas
- Direccion del beneficiario de la subasta
- Epecificaciones del producto subastado


## Algunas de las funciones de este contrato son:

- **generateBlindedBidBytes32:** Codificar y enviar un objeto de 32bits(hash = nuestra oferta)
- **bid:** Agrega la oferta de alguna persona
- **reveal:** revelar todas las ofertas incluyendo la ganadora
- **auctionEnd:** terminar la subasta y dar al beneficiario el premio
- **withdraw:** retirar los fondos de los ofertante que no ganaron
- **placeBid:** nos asuguramos que la transferecia se realize y la oferta se registre en nuestros objetos
