pragma solidity ^0.4.15;

import "./FlexibleEscrowLib.sol";
import "./ModerateEscrowLib.sol";
import "./StrictEscrowLib.sol";

contract StayBitContractFactory
{
	using BaseEscrowLib for BaseEscrowLib.EscrowContractState;
    mapping(bytes32 => BaseEscrowLib.EscrowContractState) private contracts;

	event contractCreated(int Id, string Guid);

	function StayBitContractFactory()
	{}

    //75, 1, 1533417601, 1534281601, 100, "0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db", "", "0x4514d8d91a10bda73c10e2b8ffd99cb9646620a9", 1, "test"
	function CreateContract(int rentPerDay, int cancelPolicy, uint moveInDate, uint moveOutDate, int secDeposit, address landlord, string doorLockData, address token, int Id, string Guid) public
	{
		//Check that we support cancel policy
		require (cancelPolicy == 1 || cancelPolicy == 2 || cancelPolicy == 3);

		//Check that GUID does not exist		
		require (contracts[keccak256(Guid)]._Id == 0);

		contracts[keccak256(Guid)]._CurrentDate = now;
		contracts[keccak256(Guid)]._CreatedDate = now;
		contracts[keccak256(Guid)]._RentPerDay = rentPerDay;
		contracts[keccak256(Guid)]._MoveInDate = moveInDate;
		contracts[keccak256(Guid)]._MoveOutDate = moveOutDate;
		contracts[keccak256(Guid)]._SecDeposit = secDeposit;
		contracts[keccak256(Guid)]._DoorLockData = doorLockData;
		contracts[keccak256(Guid)]._landlord = landlord;
		contracts[keccak256(Guid)]._tenant = msg.sender;
		contracts[keccak256(Guid)]._ContractAddress = this;		
		contracts[keccak256(Guid)]._tokenApi = ERC20Interface(token);
		contracts[keccak256(Guid)]._Id = Id;
		contracts[keccak256(Guid)]._Guid = Guid;
		contracts[keccak256(Guid)]._CancelPolicy = cancelPolicy;

		contracts[keccak256(Guid)].initialize();

		require(uint(contracts[keccak256(Guid)]._TotalAmount) <= contracts[keccak256(Guid)]._tokenApi.balanceOf(msg.sender));

		//Fund 
		contracts[keccak256(Guid)]._tokenApi.transferFrom(msg.sender, this, uint(contracts[keccak256(Guid)]._TotalAmount));

		contracts[keccak256(Guid)]._Balance = uint(contracts[keccak256(Guid)]._TotalAmount);

		//raise event
		contractCreated(Id, Guid);
	}

	function() payable
	{	
		revert();
	}

	function SimulateCurrentDate(uint n, string Guid) public {
	    if (contracts[keccak256(Guid)]._Id != 0)
		{
			contracts[keccak256(Guid)].SimulateCurrentDate(n);
		}
	}
	
	
	function GetContractInfo(string Guid) public constant returns (uint curDate, int escrState, int escrStage, bool tenantMovedIn, uint actualBalance, bool misrepSignaled, string doorLockData, int calcAmount, uint actualMoveOutDate, int cancelPolicy)
	{
		if (contracts[keccak256(Guid)]._Id != 0)
		{
			actualBalance = contracts[keccak256(Guid)].GetContractBalance();
			curDate = contracts[keccak256(Guid)].GetCurrentDate();
			tenantMovedIn = contracts[keccak256(Guid)]._TenantConfirmedMoveIn;
			misrepSignaled = contracts[keccak256(Guid)]._MisrepSignaled;
			doorLockData = contracts[keccak256(Guid)]._DoorLockData;
			escrStage = contracts[keccak256(Guid)].GetCurrentStage();
			escrState = contracts[keccak256(Guid)]._State;
			calcAmount = contracts[keccak256(Guid)]._TotalAmount;
			actualMoveOutDate = contracts[keccak256(Guid)]._ActualMoveOutDate;
			cancelPolicy = contracts[keccak256(Guid)]._CancelPolicy;
		}
	}
		
	function TenantTerminate(string Guid) public
	{
		if (contracts[keccak256(Guid)]._Id != 0)
		{
			require(contracts[keccak256(Guid)]._State == BaseEscrowLib.GetContractStateActive() && msg.sender == contracts[keccak256(Guid)]._tenant);

			if (contracts[keccak256(Guid)]._CancelPolicy == 1)
			{
				FlexibleEscrowLib.TenantTerminate(contracts[keccak256(Guid)]);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 2)
			{
				ModerateEscrowLib.TenantTerminate(contracts[keccak256(Guid)]);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 3)
			{
				StrictEscrowLib.TenantTerminate(contracts[keccak256(Guid)]);
			}
			else{
				revert();
			}

			SendTokens(Guid);
		}
	}

	function TenantTerminateMisrep(string Guid) public
	{	
		if (contracts[keccak256(Guid)]._Id != 0)
		{
			require(contracts[keccak256(Guid)]._State == BaseEscrowLib.GetContractStateActive() && msg.sender == contracts[keccak256(Guid)]._tenant);

			if (contracts[keccak256(Guid)]._CancelPolicy == 1)
			{
				FlexibleEscrowLib.TenantTerminateMisrep(contracts[keccak256(Guid)]);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 2)
			{
				ModerateEscrowLib.TenantTerminateMisrep(contracts[keccak256(Guid)]);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 3)
			{
				StrictEscrowLib.TenantTerminateMisrep(contracts[keccak256(Guid)]);
			}
			else{
				revert();
			}

			SendTokens(Guid);
		}
	}
    
	function TenantMoveIn(string Guid) public
	{	
		if (contracts[keccak256(Guid)]._Id != 0)
		{
			require(contracts[keccak256(Guid)]._State == BaseEscrowLib.GetContractStateActive() && msg.sender == contracts[keccak256(Guid)]._tenant);

			if (contracts[keccak256(Guid)]._CancelPolicy == 1)
			{
				FlexibleEscrowLib.TenantMoveIn(contracts[keccak256(Guid)]);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 2)
			{
				ModerateEscrowLib.TenantMoveIn(contracts[keccak256(Guid)]);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 3)
			{
				StrictEscrowLib.TenantMoveIn(contracts[keccak256(Guid)]);
			}
			else{
				revert();
			}
		}
	}

	function LandlordTerminate(uint SecDeposit, string Guid) public
	{		
		if (contracts[keccak256(Guid)]._Id != 0)
		{
			require(contracts[keccak256(Guid)]._State == BaseEscrowLib.GetContractStateActive() && msg.sender == contracts[keccak256(Guid)]._landlord);

			if (contracts[keccak256(Guid)]._CancelPolicy == 1)
			{
				FlexibleEscrowLib.LandlordTerminate(contracts[keccak256(Guid)], SecDeposit);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 2)
			{
				ModerateEscrowLib.LandlordTerminate(contracts[keccak256(Guid)], SecDeposit);
			}
			else if (contracts[keccak256(Guid)]._CancelPolicy == 3)
			{
				StrictEscrowLib.LandlordTerminate(contracts[keccak256(Guid)], SecDeposit);
			}
			else{
				revert();
			}

			SendTokens(Guid);
		}
	}

	function SendTokens(string Guid) private
	{
		
		if (contracts[keccak256(Guid)]._Id != 0)
		{
			if (contracts[keccak256(Guid)]._landlBal > 0)
			{	
				uint landlBal = uint(contracts[keccak256(Guid)]._landlBal);
				contracts[keccak256(Guid)]._landlBal = 0;		
				contracts[keccak256(Guid)]._tokenApi.transfer(contracts[keccak256(Guid)]._landlord, landlBal);
				contracts[keccak256(Guid)]._Balance -= landlBal;						
			}
	    
			if (contracts[keccak256(Guid)]._tenantBal > 0)
			{			
				uint tenantBal = uint(contracts[keccak256(Guid)]._tenantBal);
				contracts[keccak256(Guid)]._tenantBal = 0;
				contracts[keccak256(Guid)]._tokenApi.transfer(contracts[keccak256(Guid)]._tenant, tenantBal);			
				contracts[keccak256(Guid)]._Balance -= tenantBal;
			}
		}
			    
	}
}