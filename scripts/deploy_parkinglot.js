const hre = require("hardhat");

async function main() {
  // Set the total number of parking spots here
  const totalSpots = 100;

  const ParkingLot = await hre.ethers.getContractFactory("ParkingLot");
  const parkingLot = await ParkingLot.deploy(totalSpots);
  await parkingLot.deployed();
  console.log("ParkingLot deployed to:", parkingLot.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 