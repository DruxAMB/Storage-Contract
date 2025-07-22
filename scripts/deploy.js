const hre = require("hardhat");

async function main() {
  const Attendance = await hre.ethers.getContractFactory("Attendance");
  const attendance = await Attendance.deploy();
  await attendance.deployed();
  console.log("Attendance deployed to:", attendance.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 