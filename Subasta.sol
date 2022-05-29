// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

contract BlindAuction {

    ////////////////////////////// VARIABLES //////////////////////////////
    struct Bid {
        bytes32 blidedBid;                  //hash de la wallet
        uint deposit;                       //Cantidad de eter depositado
    }

    address payable public beneficiary;     //la wallet del beneficiario de la subasta
    uint public biddingEnd;                 //Cuando Finaliza de la oferta
    uint public revealEnd;                  //Cuando podemos revelar todas las y fertas y pagar al ganador
    bool public ended;                      //Si la oferta finaliso o No
    string public features;                 //Las caracteristicas del producto
    
    address public highestBidder;           //Direccion del mejor postor
    uint public highestBid;                 //Mejor oferta
    
    mapping(address => Bid[]) public bids;  /*mapeasmos las direccion en la estructura "Bid" 
                                            (lo ponemos como un arry por que cada direccion puede tener mas un bit)*/

    mapping(address => uint) public pendingRetunrs;//Retornos pendientes de los postores no ganadores


    ////////////////////////////// EVENT //////////////////////////////
    event AuctionEnded(address winneer, uint highestBid);/*Guardamos en la blockchain un evento 
                                                        que contenga al gandor y el dinero que invirtio*/                                               

    ////////////////////////////// MODIFIRS //////////////////////////////
    
    //Con este modificador nos aseguramos que algo solo suceda despues de una fecha especifica
    modifier onlyBefore(uint _time) {require(block.timestamp < _time); _;}

    //Con este modificador nos aseguramos que algo solo suceda antes de una fecha especifica
    modifier onlyAfter(uint _time) {require(block.timestamp > _time); _;}


    ////////////////////////////// FUCTIONS //////////////////////////////

    //Establecemos algunas variable utiles
    constructor(
        uint _biddingTime,                          //El tiempo que va a durar la oferta
        uint _revealTime,                           //El tiempo en que revelareremos todas las ofertas
        address payable _beneficiary,               //El Beneficiario de la subasta
        string memory _features                     //caracteristicas del producto subastado
    ){
        beneficiary = _beneficiary;                 //Establecemos que la varible beneficiary es igual a _beneficiary
        features = _features;                       //Establecemos de las carecteristicas del producto
        biddingEnd = block.timestamp + _biddingTime;//Establecemos que el final de la subasta va a ser el tiempo estimado + el tiempo actual
        revealEnd = biddingEnd + _revealTime;       //Establecemos que la revelacon va a ser el tiempo estimado + el final de la subasata
    }
    
    //Codificar y enviar un objeto de 32bits(hash = nuestra oferta)
    function generateBlindedBidBytes32(uint value, bool fake) public view returns(bytes32){
        //Retornamos un hash echo a partir de un valor que introdujo el usuario(value) y un booleano(fake)
        return keccak256(abi.encodePacked(value, fake));

    }
    
    /*Tomara un valor hash(generado por "generateBlindedBidBytes32")
    Asemos esto por que las personas pueden ver las transaciones escritas en
    la blockchain y si no lo encryptamos No seria una subasta a siegas
    (lo que vamos a registrar un la blockchain es el hash)*/
    function bid(bytes32 _blindedBid) public payable onlyBefore(biddingEnd){
        
        //agregamos a nuestra matris dinamica bids el valor que alguein quiere depositar y su "_blindedBid"
        bids[msg.sender].push(Bid({
            blidedBid: _blindedBid,//_blindedBid == generateBlindedBidBytes32
            deposit: msg.value
            }));
    }

    // revelar todas las ofertas incluyendo la ganadora
    // Hacemos que esta solo se pueda ejecutar despues del tiempo de espera establececido para revelar la subasta
    // Como argumentos tomamos una lista de valores y una lista para ver si esos valores son verdaderos
    function reveal(uint[] memory _values, bool[] memory _fake) public onlyAfter(biddingEnd) onlyBefore(revealEnd){
        //En esta variable vamos a guardar la logitud de la matriz de las ofertas del suario
        uint length = bids[msg.sender].length;
        
        //Nos aseguramos que la logiud de la matriz dada como argumeto sea igual a length
        require(_values.length == length);
        require(_fake.length == length);
        
        //Esta variable alacena la cantidad que se debe rembolsar a los usuarios perdedores
        uint refund;
        
        //hacemos un loop para recorre la matriz length
        for (uint i=0; i<length; i++){

            Bid storage bidToCheck = bids[msg.sender][i];       //establecemos bidToCheck como la oferta del usuario en la itaracion actual
            (uint value, bool fake) = (_values[i], _fake[i]);   /*establecemos "value" va aser igual a el "_value" de la iteracion actual
                                                                y que "fake" va ser igual que el "_fake" de la itarecion actual*/

            /*Aqui se verifica si el "bidToCheck.blidedBid"(hash de la transacion) 
            sea igual a un nuevo hash si se crea con los mismo valores*/
            if (bidToCheck.blidedBid != keccak256(abi.encodePacked(value, fake))){
                continue;// si es asi siguienmos en el codigo sin hacer ningun cambio
            }

            refund += bidToCheck.deposit;                       //"refund" va a ser igual a "refund" mas el deposito de la itaracion actual
            
            if(!fake && bidToCheck.deposit >= value){           /*verificamos si el valor que ingresado el usuario es falso y 
                                                                ademas verificamos si el deposito es igual o mayor al de la anterior iteracion*/
                
                // verificamos si la funcion "placeBid" se ejecuta correctamente con la wallet y el valor del usuario
                if(placeBid(msg.sender, value)){         
                    /*Vamos a transferir el rembolso al usuraio
                    (multuplicamos por un 1 ether por que queremos trabarjar con ether y no con wei)*/
                    payable(msg.sender).transfer(bidToCheck.deposit * (1 ether));

                }
            }
            //Restablecemos el hash a 0 (para que nadie mas lo pueda usar)
            bidToCheck.blidedBid = bytes32(0);
        }
    }

    // terminar la subasta y dar al beneficiario el premio
    function auctionEnd() public payable onlyAfter(revealEnd){
        
        require(!ended);                                //No aseguramos que la subasta alla terminado
        emit AuctionEnded(highestBidder, highestBid);   //Emitimos direccion del mejor postor y su apuesta  
        ended = true;                                   //Establecemos que ha terminado la subasta
        beneficiary.transfer(highestBid);               //Le damos al beneficiario la apuesta mas alta

    }

    // retirar los fondos de los ofertante que no ganaron
    function withdraw() public{
        uint amount = pendingRetunrs[msg.sender];/*amount es igual ala cantidad que se 
                                                tinen que devolver a cada direccion*/
        
        //Nos aseguramos de que se le deba devolder algo de eter a la persona
        if (amount > 0){   
            pendingRetunrs[msg.sender] = 0;         //Reducimos la deuda que teniamos que esa direccion a 0
            payable(msg.sender).transfer(amount);   //Le enviamos el eter que posto
        }

    }
    
    // nos asuguramos que la transferecia se realize y la oferta se registre en nuestros objetos
    function placeBid(address bidder, uint value) internal returns(bool success){
        //Primero nos aseguramos que la nueva oferta se mas grande que la anterior
        if(value <= highestBid){
            return false;
        }
        
        //Despues que la nueva direccion no sea la dereccion de que de monedas(0x000000000000000)
        if (highestBidder != address(0)){
            pendingRetunrs[highestBidder] += highestBid;
        }

        highestBid = value;     //Establecemos la nueva oferta como la oferta mas grande
        highestBidder = bidder; //Establecemos el nuevo postor como el mejor postor
        return true;            //Retornamos True para indicar que todo salio bien

    }
}
