//SPDX-License-Identifier:
pragma solidity ^0.8.28; 

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract Store is Ownable {

    uint256 totalRevenue;

    /// @notice buyer => product_id => quantity
    mapping(address => mapping(uint256 => uint256)) private userPurchase;
    /// @notice product_id => quantity
    mapping(uint256 => uint256) private productPurchase;
    /// @notice buyer => Purchase
    mapping(address => Purchase[]) private userPurchases;
    /// @notice dicountCode => discoutAmount (0-90)
    mapping(string => uint256) private discountCodes;

    

    struct Product { 
        string name;
        uint id;
        uint256 stock;
        uint256 price;
        
    }

    struct Purchase {
        uint256 productId;
        uint256 quantity;
        uint256 paidPrice;
        uint256 timestamp;

    }

    Product[] private products;
    /// @notice throw when caller is not an owner


    event PurchaseMade(address buyer, uint256 id, uint256 quantity, uint256 paidPrice);
    event ReturnMade(address buyer, uint256 id, uint256 quantity, uint256 price);

    error IdAlreadyExist();
    error IdDoesNotExist();
    error OutOfStock();
    error NotEnoughFunds();
    error QuantityCantBeZero();
    error UserHasNoPurchases();
    error CantRefundAfter24h();
    error DontHaveMoneyForReturn();
    error InvalidDiscountAmount();
    error CodeAreadyExist();
    error CodeDoesNotExist();
        
    
    constructor() Ownable(msg.sender) {}


    function gettopSellingProducts() external view returns(string memory) {
        uint256 topSell = products[0].stock;
        uint256 t;
        for(uint i=0;i < products.length; i++) {
            if( products[i].stock > topSell) {
                topSell = products[i].stock;
                t = i; }


            
        return products[t].name;



        }
        




    }
   // function refund(uint256 _id, uint256 _quantity) external payable {
   //     uint256 moneyBack = getPrice(_id) * _quantity;
   //     payable(owner()).transfer(moneyBack);
   // }


    function buy(uint256 _id, uint256 _quantity, string calldata discountCode) external payable {

        require(_quantity >0, QuantityCantBeZero());
        require(getStock(_id) >= _quantity, OutOfStock() );

        uint256 discount = discountCodes[discountCode];
        uint256 totalPrice = getPrice(_id) * _quantity;


        if(discount > 0) {
            totalPrice = (totalPrice * (100-discount) / 100);
        }
        require(msg.value >= totalPrice, NotEnoughFunds());
         //buy
        buyProcess(msg.sender, _id, _quantity, totalPrice);

        if(msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value -totalPrice);

        }
        


    }

    function buyProcess(address buyer, uint256 _id, uint256 _quantity,uint256 _paidPrice) internal {
        Product storage product = findProduct(_id);
        product.stock -= _quantity;

        userPurchase[buyer][_id] += _quantity;
        productPurchase[_id] += _quantity;
        totalRevenue += _paidPrice;


        userPurchases[buyer].push(Purchase(_id,_quantity,_paidPrice, block.timestamp));

        emit PurchaseMade(buyer,_id,_quantity, _paidPrice);


    }

    function refund() public {
        require(userPurchases[msg.sender].length > 0, UserHasNoPurchases());

        Purchase storage lastPurchase = userPurchases[msg.sender][userPurchases[msg.sender].length-1];
        Product storage product = findProduct(lastPurchase.productId);
        require(address(this).balance >= lastPurchase.paidPrice, DontHaveMoneyForReturn());
        require(block.timestamp - lastPurchase.timestamp <=  1 days,CantRefundAfter24h());

        userPurchase[msg.sender][lastPurchase.productId] -= lastPurchase.quantity;
        productPurchase[lastPurchase.productId] -= lastPurchase.quantity;
        totalRevenue -= lastPurchase.paidPrice;
        product.stock+= lastPurchase.quantity;
        payable(msg.sender).transfer(lastPurchase.paidPrice);






        emit ReturnMade(msg.sender, lastPurchase.productId, lastPurchase.quantity, lastPurchase.paidPrice );

        userPurchases[msg.sender].pop();
        
        

          
    }




    

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Not enough money");

        payable(owner()).transfer(balance);
    }


    function batchBuy(uint256[] calldata _ids, uint256[] calldata _quantitys, string calldata discountCode) payable external {

        require( _ids.length == _quantitys.length, "arrays lengths mismatch");

        uint256 totalPrice = 0;

        for(uint i = 0; i < _ids.length; i++) {
           uint256 q = _quantitys[i];
           uint256 id = _ids[i];

            require(q > 0, QuantityCantBeZero());
            require(getStock(id) >= q, OutOfStock() );
            totalPrice += getPrice(id)*q ;     

        }
        uint256 discount = discountCodes[discountCode];
    
          if(discount > 0) {
            totalPrice = (totalPrice * (100-discount) / 100);
        }


        require(msg.value >= totalPrice, NotEnoughFunds());
        for(uint i = 0; i < _ids.length; i++) {
            uint256 q = _quantitys[i];
            uint256 id = _ids[i];
            buyProcess(msg.sender, id, q, totalPrice);

            if(msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value -totalPrice);

        }

        }

    }


    function addProduct(string calldata _name, uint256 _id, uint256 _stock, uint256 _price) external onlyOwner {
        require(!isIdExist(_id), IdAlreadyExist());
        products.push(Product(_name, _id, _stock, _price));

    }

    function addDiscountCode(string calldata code, uint256 discountAmount) external onlyOwner {
        require(discountAmount > 0 && discountAmount <=90, InvalidDiscountAmount());
        require(discountCodes[code] == 0, CodeAreadyExist());


        discountCodes[code] = discountAmount;


    }


    function deleteDiscountCode(string calldata code) external onlyOwner {
        require(discountCodes[code] > 0, CodeDoesNotExist());
        
        delete discountCodes[code];

    }

    function getTotalRevenue() public view returns(uint256) {
        return totalRevenue;
    }
    
    
    
    function deleteProduct(uint256 _id) external onlyOwner {
        (bool status, uint256 index ) = findIndexById(_id);
        require(status, IdDoesNotExist());
        products[index] = products[products.length-1];
        products.pop();

    }

    function updatePrice(uint256 _id, uint256 _price) external onlyOwner {
        Product storage product= findProduct(_id);
        product.price = _price;


    }

    function getUserPurchases(address buyer) public view returns(Purchase[] memory ) {
        return userPurchases[buyer];
    }
    
    function getProducts() public view returns(Product[] memory) {
        return products;
    }


    function updateStock(uint256 _id, uint256 _stock) external onlyOwner {
        Product storage product = findProduct(_id);
        product.stock = _stock;


    }


    function getPrice(uint256 _id) public view returns(uint256) {
        Product storage product = findProduct(_id);
        return product.price;
    }

    function getStock(uint256 _id) public view returns(uint256) {
        Product storage product = findProduct(_id);
        return product.stock;
    }


    function findProduct(uint256 _id) internal view returns(Product storage product) {
        for(uint i = 0; i < products.length; i++) {
            if (products[i].id ==  _id) {
                return products[i];
            }

        }

        revert IdDoesNotExist();

    }


    function isIdExist(uint256 _id) internal view returns(bool) {
        for( uint i = 0; i < products.length; i++) {
            if(products[i].id == _id) {
                return true;
            }
        }
        return false;
    }
    
    function findIndexById(uint256 _id) internal view returns(bool, uint256) {
        for(uint i = 0; i < products.length; i++) {
            if(products[i].id == _id) {
                return (true, i);
            }

        }
        return (false, 0);
    }







}