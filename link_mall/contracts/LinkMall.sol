pragma solidity ^0.4.19;
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";

contract Ownable {
  address public _owner;

  constructor(address owner) public {
    _owner = owner;
  }

  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    _owner = newOwner;
  }
}


contract LinkMall is Ownable {

    using SafeMath for uint;

  // 订单项
    struct OrderItem {
        uint productId;
        // 下单时的商品单价
        uint price;
        uint16 count;
    }

    // 订单
    struct Order {
        OrderItem[] items;
        address payer;
    }

 
    // 商品
    struct Product {
        bytes32 name;
        uint price;
        uint8 status;
    }

    // 保存商品信息(itemid => item)
    mapping(uint => Product) public _products;

    // 保存订单信息(orderid => item)
    mapping(uint => Order) public _orders; 

    constructor(address owner) Ownable(owner) public {}

    // 设置商品
    function setProduct(uint productid, bytes32 name, uint price, uint8 status) onlyOwner public {
      require(status > 0);
      _products[productid] = Product({
        name: name,
        price: price,
        status: status
      });
   }

   // 查看商品
    function getProduct(uint productid) view public returns (bytes32, uint, uint8) {
      Product memory product = _products[productid];
      return (product.name, product.price, product.status);
    }

    // 提交订单
    function setOrder(uint orderid, uint[] productid, uint16[] count) payable public {
      // 单个订单不能超过100种商品
      require(productid.length < 100 && productid.length > 0 && productid.length == count.length);


      // 防止重复支付
      Order memory order = _orders[orderid];
      require(order.items.length == 0);

      uint totalPrice = 0;
      uint productAmount = 0;

      // 设置订单信息
      for(uint i = 0; i < productid.length; i++) {
        require(count[i] > 0);
        Product memory product = _products[productid[i]];
        require(product.status > 0);
        productAmount = product.price.mul(count[i]);
        totalPrice = totalPrice.add(productAmount);

        _orders[orderid].items.push(OrderItem({
          productId: productid[i],
          price: product.price,
          count: count[i]
        }));
        _orders[orderid].payer = msg.sender;
      }

      // 校验一下付款金额
      require(totalPrice == msg.value);

      // 转账给商家
      if(msg.value > 0) {
        _owner.transfer(msg.value);
      }
    }

    // 查询订单
    function getOrder(uint orderid) view public returns (address, uint) {
      Order memory order = _orders[orderid];
      return (order.payer, order.items.length);
    }

    // 查询订单项
    function getOrderItem(uint orderid, uint i) view public returns (uint, uint, uint16) {
      OrderItem memory item = _orders[orderid].items[i];
      return (item.productId, item.price, item.count);
    }
}

