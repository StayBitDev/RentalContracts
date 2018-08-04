pragma solidity ^0.4.15;

import "./FlexibleEscrowLib.sol";
import "./ModerateEscrowLib.sol";
import "./StrictEscrowLib.sol";

contract StayBitContract
{
	using BaseEscrowLib for BaseEscrowLib.EscrowContractState;
    BaseEscrowLib.EscrowContractState private state;
    

    modifier onlyLandlord {
        require(state._State == BaseEscrowLib.GetContractStateActive() && msg.sender == state._landlord);
        _;
    }

    modifier onlyTenant {
        require(state._State == BaseEscrowLib.GetContractStateActive() && msg.sender == state._tenant);
        _;
    }

    //75, 1, 1522540800, 1523145600, 100, "0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db", ""
	function StayBitContract(int rentPerDay, int cancelPolicy, uint moveInDate, uint moveOutDate, int secDeposit, address landlord, string doorLockData, address token, int Id) public
	{
		state._CurrentDate = now;
		state._CreatedDate = now;
		state._RentPerDay = rentPerDay;
		state._MoveInDate = moveInDate;
		state._MoveOutDate = moveOutDate;
		state._SecDeposit = secDeposit;
		state._DoorLockData = doorLockData;
		state._landlord = landlord;
		state._tenant = msg.sender;
		state._ContractAddress = this;		
		state._tokenApi = ERC20Interface(token);
		state._Id = Id;		
		state._CancelPolicy = cancelPolicy;

		//Check that we support cancel policy
		require (cancelPolicy == 1 || cancelPolicy == 2 || cancelPolicy == 3);

		state.initialize();
	}

	function() payable
	{	
		revert();
	}

	function SimulateCurrentDate(uint n) public {
	    state.SimulateCurrentDate(n);
	}
	
	
	function GetContractInfo() public constant returns (uint curDate, int escrState, int escrStage, bool tenantMovedIn, uint actualBalance, bool misrepSignaled, string doorLockData, int calcAmount, uint actualMoveOutDate, int cancelPolicy)
	{
	    actualBalance = state.GetContractBalance();
	    curDate = state.GetCurrentDate();
	    tenantMovedIn = state._TenantConfirmedMoveIn;
	    misrepSignaled = state._MisrepSignaled;
	    doorLockData = state._DoorLockData;
	    escrStage = state.GetCurrentStage();
	    escrState = state._State;
		calcAmount = state._TotalAmount;
		actualMoveOutDate = state._ActualMoveOutDate;
		cancelPolicy = state._CancelPolicy;
	}
		
	function TenantTerminate() onlyTenant public
	{
		if (state._CancelPolicy == 1)
		{
			FlexibleEscrowLib.TenantTerminate(state);
		}
		else if (state._CancelPolicy == 2)
		{
			ModerateEscrowLib.TenantTerminate(state);
		}
		else if (state._CancelPolicy == 3)
		{
			StrictEscrowLib.TenantTerminate(state);
		}
		else{
			revert();
		}

		SendTokens();
	}

	function TenantTerminateMisrep() onlyTenant public
	{	
		if (state._CancelPolicy == 1)
		{
			FlexibleEscrowLib.TenantTerminateMisrep(state);
		}
		else if (state._CancelPolicy == 2)
		{
			ModerateEscrowLib.TenantTerminateMisrep(state);
		}
		else if (state._CancelPolicy == 3)
		{
			StrictEscrowLib.TenantTerminateMisrep(state);
		}
		else{
			revert();
		}

		SendTokens();
	}
    
	function TenantMoveIn() onlyTenant public
	{	
		if (state._CancelPolicy == 1)
		{
			FlexibleEscrowLib.TenantMoveIn(state);
		}
		else if (state._CancelPolicy == 2)
		{
			ModerateEscrowLib.TenantMoveIn(state);
		}
		else if (state._CancelPolicy == 3)
		{
			StrictEscrowLib.TenantMoveIn(state);
		}
		else{
			revert();
		}
	}

	function LandlordTerminate(uint SecDeposit) onlyLandlord public
	{		
		if (state._CancelPolicy == 1)
		{
			FlexibleEscrowLib.LandlordTerminate(state, SecDeposit);
		}
		else if (state._CancelPolicy == 2)
		{
			ModerateEscrowLib.LandlordTerminate(state, SecDeposit);
		}
		else if (state._CancelPolicy == 3)
		{
			StrictEscrowLib.LandlordTerminate(state, SecDeposit);
		}
		else{
			revert();
		}

		SendTokens();
	}

	function SendTokens() private
	{
	    if (state._landlBal > 0)
	    {	
			uint landlBal = uint(state._landlBal);
			state._landlBal = 0;		
	        state._tokenApi.transfer(state._landlord, landlBal);						
	    }
	    
	    if (state._tenantBal > 0)
	    {			
	        uint tenantBal = uint(state._tenantBal);
			state._tenantBal = 0;
			state._tokenApi.transfer(state._tenant, tenantBal);			
	    }	    
	}
}