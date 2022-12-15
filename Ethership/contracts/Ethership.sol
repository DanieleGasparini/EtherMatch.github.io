//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

contract Ethership {
    address owner;
    uint public totalShipments = 0;

    enum Incoterm {
        NONE,
        EXW,
        FCA,
        CPT
    }

    enum Status {
        OnSale,
        Ordered,
        FailuredBeforeTransit,
        InTransit,
        FailureBeforeDelivery,
        Delivered
    }

    struct Shipment {
        uint id;
        uint price;
        string title;
        Incoterm contracted_incoterm;
        Status status;
        address seller;
        address shipper;
        address buyer;
        string shipper_notes;
    }

    mapping(uint => Shipment) public shipments;
    mapping(address => uint) public shippersBalance;
    mapping(address => uint) public sellersBalance;
    mapping(address=>string) public allowedShippersName;
    address[] public allowedShippersAddress;

    constructor() {
        owner = msg.sender;
    }

    // updateOwner
    function updateOwner(address _newOwner) public{
        require(msg.sender==owner,"You are not allowed to change the ownership");
        owner = _newOwner;
    }

    // this gets executed by a seller
    function createShipment(uint _price, string memory _title) public {
        require(bytes(_title).length > 0);
        require(_price > 0);

        uint _id = totalShipments;
        Incoterm _contracted_incoterm = Incoterm.NONE;
        Status _status = Status.OnSale;
        address _seller = msg.sender;
        address _shipper = address(0);
        address _buyer = address(0);
        string memory _notes = "";
        shipments[_id] = Shipment(_id, _price, _title, _contracted_incoterm, _status, _seller, _shipper, _buyer, _notes);

        totalShipments++;
    }

    //createShipper
    function createShipper(string memory _shipperName, address _shipperAddress) public {
        require(msg.sender==owner,"You are not allowed to add new shippers ");
        allowedShippersName[_shipperAddress] = _shipperName;
        allowedShippersAddress.push(_shipperAddress);
    }
    //deleteShipper
    function deleteShipper(address _shipperAddress) public {
        require(msg.sender==owner,"You are not allowed to delete shippers");
        // find and delete shipperAddress from the array of shippers
        uint _index = 0;
        while (allowedShippersAddress[_index] != _shipperAddress){
            _index++;
        }
        allowedShippersAddress[_index] = allowedShippersAddress[allowedShippersAddress.length - 1];
        allowedShippersAddress.pop();
        
        // deleteShipperAddress from the name mappings
        allowedShippersName[_shipperAddress] = "";

        // send any remaining balance to the shipper
        if(shippersBalance[_shipperAddress]>0) {
            //Withdraw the balance og the shipper
            uint balance = shippersBalance[_shipperAddress];
            payable(_shipperAddress).transfer(balance);
        }
    }


    // this gets executed by a buyer
    function buyShipment(uint _id, Incoterm _selected_incoterm, address _shipper) public payable {
        require(_selected_incoterm != Incoterm.NONE, "Must choose one of the avaialble incoterms");
        // TODO: Create a list of available shipper
        require(_shipper != address(0), "Must select a shipper");

        Shipment memory _shipment = shipments[_id];
        require(_shipment.price > 0, "Shipment not existant");

        require(msg.value == _shipment.price, "Buyer needs to pay the exact price");

        _shipment.contracted_incoterm = _selected_incoterm;
        _shipment.status = Status.Ordered;
        _shipment.shipper = _shipper;
        _shipment.buyer = msg.sender;

        shipments[_id] = _shipment;
    }

    // this gets executed by the shipper
    function updateShipment(uint _id, Status _status, string memory _notes) public{
        require(_status != Status.OnSale, "Must select a valid status");
        require(_status != Status.Ordered, "Must select a valid status");
        
        Shipment memory _shipment = shipments[_id];
        require(_shipment.price > 0, "Shipment not existant");
        //If shipment is in state FailuredBeforeTransit,FailureBeforeDelivery or Delivered, then it can't be accessed anymore, 
        //you can't put a status that is lower than the actual status
        require(_shipment.status != Status.Delivered, "Can't set the status as a delivered twice");
        require(_shipment.status != Status.FailureBeforeDelivery, "Can't recover a shipment if it failed");
        require(_shipment.status != Status.FailuredBeforeTransit, "Can't recover a shipment if it failed");
        require(_status>_shipment.status,"Can't select a state that is lower than the actual one");
        //The function caller must be the shipment shipper
        require(_shipment.shipper==msg.sender,"You are not allowed to change this shipment status");
        _shipment.status = _status;
        _shipment.shipper_notes = _notes;

        uint _shipper_rev = _shipment.price / 10;
        uint _seller_rev = _shipment.price;

        // If Shipment is delivered, seller only gets 90%
        // If Incoterm (like the insurance happens), seller gets 100%
        if (_shipment.status == Status.Delivered){
            shippersBalance[_shipment.shipper] += _shipper_rev;
            _seller_rev = _shipment.price - _shipper_rev;
        }

        bool updateSellerBalance = !canBuyerWithdrawFunds(_shipment.contracted_incoterm, _shipment.status);

        if (updateSellerBalance && _shipment.status != Status.InTransit){
            sellersBalance[_shipment.seller] += _seller_rev;
        }

        shipments[_id] = _shipment;
        
    }

    function canBuyerWithdrawFunds(Incoterm _incoterm, Status _status) public pure returns (bool){
        /*
        CanBuyerWithdrawFunds
        DELIVERED = NEI_MONEY
        EXW,  (FailuredBeforeTransit, FailureBeforeDelivery) = (NEI_MONEY, NEI_MONEY)
        FCA,  (FailuredBeforeTransit, FailureBeforeDelivery) = (YEI_MONEY, NEI_MONEY)
        CPT,  (FailuredBeforeTransit, FailureBeforeDelivery) = (YEI_MONEY, YEI_MONEY)

        CanSellerWithdrawFunds == !CanBuyerWithdawFunds
        DELIVERED = YEI_MONEY
        EXW,  (FailuredBeforeTransit, FailureBeforeDelivery) = (YEI_MONEY, YEI_MONEY)
        FCA,  (FailuredBeforeTransit, FailureBeforeDelivery) = (NEI_MONEY, YEI_MONEY)
        CPT,  (FailuredBeforeTransit, FailureBeforeDelivery) = (NEI_MONEY, NEI_MONEY)
        */
        
        if (_status == Status.Delivered){
            return false;
        }

        // Incoterms cover the FailureBeforeTransit and FailureBeforeDelivery
        if (_incoterm == Incoterm.EXW && _status == Status.FailuredBeforeTransit){
            return false;
        }

        if (_incoterm == Incoterm.EXW && _status == Status.FailureBeforeDelivery){
            return false;
        }

        if (_incoterm == Incoterm.FCA && _status == Status.FailuredBeforeTransit){
            return true;
        }

        if (_incoterm == Incoterm.FCA && _status == Status.FailureBeforeDelivery){
            return false;
        }

        if (_incoterm == Incoterm.CPT && _status == Status.FailuredBeforeTransit){
            return true;
        }

        if (_incoterm == Incoterm.CPT && _status == Status.FailureBeforeDelivery){
            return true;
        }
        return false;
    }

    function buyerWithdraw(uint _id) public {
        Shipment memory _shipment = shipments[_id];
        require(_shipment.price > 0, "Shipment not existant");

        require(_shipment.buyer == msg.sender, "You are not the buyer of this shipment");

        require(_shipment.status != Status.Ordered, "You are not allowed to withdraw funds, while shipment is Orderd");
        require(_shipment.status != Status.InTransit, "You are not allowed to withdraw funds, while shipment is InTransit");

        bool canWithdraw = canBuyerWithdrawFunds(_shipment.contracted_incoterm, _shipment.status);
        require(canWithdraw, "You are not allowed to withdraw funds");

        payable(_shipment.buyer).transfer(_shipment.price);
    }
    function sellerWithdraw() public {
        uint balance = sellersBalance[msg.sender];
        require(balance > 0, "Your balance must be positive");

        payable(msg.sender).transfer(balance);
    }
    function shipperWithdraw() public {
        uint balance = shippersBalance[msg.sender];
        require(balance > 0, "Your balance must be positive");

        payable(msg.sender).transfer(balance);
    }



}