const Web3 = require('web3');
const contract = require('truffle-contract');
const shipperJson = require('../build/contracts/Shipper.json');

// initialize web3 and the shipper contract
const provider = new Web3.providers.HttpProvider('http://localhost:8545');
const web3 = new Web3(provider);
const Shipper = contract(shipperJson);
Shipper.setProvider(provider);

// get the shipper name and shipments from the contract
const shipper = await Shipper.deployed();
const shipperName = await shipper.name();
const shipments = await shipper.getShipments();

// generate the html file
let html = `
<!DOCTYPE html>
<html>
<head>
    <title>${shipperName}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f2f2f2;
        }
        h1 {
            text-align: center;
            padding: 30px;
            background-color: #337ab7;
            color: white;
        }
        h2 {
            padding: 20px;
            text-align: center;
        }
        ul {
            list-style-type: none;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
        }
        li {
            padding: 10px;
        }
        a {
            text-decoration: none;
            color: #337ab7;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <h1>${shipperName}</h1>
    <h2>Table of Contents</h2>
    <ul>`;

for (let i = 0; i < shipments.length; i++) {
    html += `<li><a href="shipment${i+1}.html">Shipment ${i+1}</a></li>`;
}

html += `
    </ul>
</body>
</html>`;

console.log(html);