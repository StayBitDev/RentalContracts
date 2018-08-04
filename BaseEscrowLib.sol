pragma solidity ^0.4.15;

import "./DateTime.sol";


// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


library BaseEscrowLib
{
    struct EscrowContractState { 
		uint _CurrentDate;
		uint _CreatedDate;
		int _RentPerDay;
		uint _MoveInDate;
		uint _MoveOutDate;				
		int _TotalAmount;					
		int _SecDeposit;
		int _State;	
		uint _ActualMoveInDate;
		uint _ActualMoveOutDate;
		address _landlord;
		address _tenant;
		bool _TenantConfirmedMoveIn;		
		bool _MisrepSignaled;			
		string _DoorLockData;
		address _ContractAddress;		
		ERC20Interface _tokenApi;
		int _landlBal;
		int _tenantBal;
		int _Id;
		int _CancelPolicy;
		uint _Balance;
		string _Guid;
    }

    //Define public constants
	//Pre-Move In
	int internal constant ContractStateActive = 1;
	int internal constant ContractStateCancelledByTenant = 2;
	int internal constant ContractStateCancelledByLandlord = 3;

	//Move-In
	int internal constant ContractStateTerminatedMisrep = 4;

	//Living
	int internal constant ContractStateEarlyTerminatedByTenant = 5;
	int internal constant ContractStateEarlyTerminatedByTenantSecDep = 6;
	int internal constant ContractStateEarlyTerminatedByLandlord = 7;		

	//Move-Out
	int internal constant ContractStateTerminatedOK = 8;	
	int internal constant ContractStateTerminatedSecDep = 9;
	
	//Stages
	int internal constant ContractStagePreMoveIn = 0;
	int internal constant ContractStageLiving = 1;
	int internal constant ContractStageTermination = 2;

	//Action
	int internal constant ActionKeyTerminate = 0;
	int internal constant ActionKeyMoveIn = 1;	
	int internal constant ActionKeyTerminateMisrep = 2;	
	int internal constant ActionKeyPropOk = 3;
	int internal constant ActionKeyClaimDeposit = 4;

	//Log
	int internal constant LogMessageInfo = 0;
	int internal constant LogMessageWarning = 1;
	int internal constant LogMessageError = 2;

	event logEvent(int stage, int atype, uint timestamp, string guid, string text);

	bool private constant EnableSimulatedCurrentDate = true;


	//LogEvent wrapper
	function ContractLogEvent(int stage, int atype, uint timestamp, string guid, string text) public
	{
		logEvent(stage, atype, timestamp, guid, text);
	}

	//Constant function wrappers
	function GetContractStateActive() public constant returns (int)
	{
		return ContractStateActive;
	}

	function GetContractStateCancelledByTenant() public constant returns (int)
	{
		return ContractStateCancelledByTenant;
	}

	function GetContractStateCancelledByLandlord() public constant returns (int)
	{
		return ContractStateCancelledByLandlord;
	}
	
	function GetContractStateTerminatedMisrep() public constant returns (int)
	{
		return ContractStateTerminatedMisrep;
	}

	function GetContractStateEarlyTerminatedByTenant() public constant returns (int)
	{
		return ContractStateEarlyTerminatedByTenant;
	}

	function GetContractStateEarlyTerminatedByTenantSecDep() public constant returns (int)
	{
		return ContractStateEarlyTerminatedByTenantSecDep;
	}

	function GetContractStateEarlyTerminatedByLandlord() public constant returns (int)
	{
		return ContractStateEarlyTerminatedByLandlord;		
	}

	function GetContractStateTerminatedOK() public constant returns (int)
	{
		return ContractStateTerminatedOK;	
	}

	function GetContractStateTerminatedSecDep() public constant returns (int)
	{
		return ContractStateTerminatedSecDep;
	}
	
	function GetContractStagePreMoveIn() public constant returns (int)
	{
		return ContractStagePreMoveIn;
	}

	function GetContractStageLiving() public constant returns (int)
	{
		return ContractStageLiving;
	}

	function GetContractStageTermination() public constant returns (int)
	{
		return ContractStageTermination;
	}
	
	function GetLogMessageInfo() public constant returns (int)
	{
		return LogMessageInfo;
	}

	function GetLogMessageWarning() public constant returns (int)
	{
		return LogMessageWarning;
	}

	function GetLogMessageError() public constant returns (int)
	{
		return LogMessageError;
	}


	//////////////////////////////////////////////////////////////////////////////////////////////////////////////
	function initialize(EscrowContractState storage self) {

		//Check parameters
		//all dates must be in the future

		require(self._CurrentDate < self._MoveInDate);
		require(self._MoveInDate < self._MoveOutDate);
							
		int nPotentialBillableDays = (int)(self._MoveOutDate - self._MoveInDate) / (60 * 60 * 24);
		int nPotentialBillableAmount = nPotentialBillableDays * (self._RentPerDay);
		
		self._TotalAmount = nPotentialBillableAmount + self._SecDeposit;
				
		//Sec Deposit should not be more than 30 perecent
		require (self._SecDeposit / nPotentialBillableAmount * 100 <= 30);
				

		self._TenantConfirmedMoveIn = false;
		self._MisrepSignaled = false;
		self._State = GetContractStateActive();
		self._ActualMoveInDate = 0;
		self._ActualMoveOutDate = 0;
		self._landlBal = 0;
		self._tenantBal = 0;
	}


	function TerminateContract(EscrowContractState storage self, int tenantBal, int landlBal, int state) public
	{
		int stage = GetCurrentStage(self);
		uint nCurrentDate = GetCurrentDate(self);
		int nActualBalance = int(GetContractBalance(self));

		if (nActualBalance == 0)
		{
		    //If it was unfunded, just change state
		    self._State = state;   
		}
		else if (self._State == ContractStateActive && state != ContractStateActive)
		{
			//Check if some balances are negative
			if (landlBal < 0)
			{
				tenantBal += landlBal;
				landlBal = 0;
			}

			if (tenantBal < 0) {
				landlBal += tenantBal;
				tenantBal = 0;
			}

			//Check if balances exceed total amount
			if ((landlBal + tenantBal) > nActualBalance)
			{
				var nOverrun = (landlBal + tenantBal) - self._TotalAmount;
				landlBal -= (nOverrun / 2);
				tenantBal -= (nOverrun / 2);
			}

			self._State = state;

			string memory strState = "";

			if (state == ContractStateTerminatedOK)
			{
				strState = " State is: OK";
			}
			else if (state == ContractStateEarlyTerminatedByTenant)
			{
				strState = " State is: Early terminated by tenant";
			}
			else if (state == ContractStateEarlyTerminatedByTenantSecDep)
			{
				strState = " State is: Early terminated by tenant, Security Deposit claimed";
			}
			else if (state == ContractStateEarlyTerminatedByLandlord)
			{
				strState = " State is: Early terminated by landlord";
			}
			else if (state == ContractStateCancelledByTenant)
			{
				strState = " State is: Cancelled by tenant";
			}
			else if (state == ContractStateCancelledByLandlord)
			{
				strState = " State is: Cancelled by landlord";
			}
			else if (state == ContractStateTerminatedSecDep)
			{
				strState = " State is: Security Deposit claimed";
			}
		
			
			
			bytes32 b1;
			bytes32 b2;
			b1 = uintToBytes(uint(landlBal));
			b2 = uintToBytes(uint(tenantBal));

                        /*
		    string memory s1;
		    string memory s2;	
		    s1 = bytes32ToString(b1);
		    s2 = bytes32ToString(b2);
                        */
			
			string memory strMessage = strConcat(
			    "Contract is termintaing. Landlord balance is _$b_", 
			    bytes32ToString(b1), 
			    "_$e_, Tenant balance is _$b_", 
			    bytes32ToString(b2));

            
			string memory strMessage2 = strConcat(
				strMessage,
				"_$e_.",
				strState
			);

            string memory sGuid;
            sGuid = self._Guid;
			
            logEvent(stage, LogMessageInfo, nCurrentDate, sGuid, strMessage2);
            
			//Send tokens
			self._landlBal = landlBal;
			self._tenantBal = tenantBal;
		}	
	}

	function GetCurrentStage(EscrowContractState storage self) public constant returns (int stage)
	{
		uint nCurrentDate = GetCurrentDate(self);
		uint nActualBalance = GetContractBalance(self);
        
        stage = ContractStagePreMoveIn;
        
		if (self._State == ContractStateActive && uint(self._TotalAmount) > nActualBalance)
		{
			//Contract unfunded
			stage = ContractStagePreMoveIn;
		}		
		else if (DateTime.compareDatesWithoutTime(nCurrentDate, self._MoveInDate) < 0)
		{
			stage = ContractStagePreMoveIn;
		}
		else if (DateTime.compareDatesWithoutTime(nCurrentDate, self._MoveInDate) >= 0 && 
		         DateTime.compareDatesWithoutTime(nCurrentDate, self._MoveOutDate) < 0 && 
		         self._TenantConfirmedMoveIn)
		{
			stage = ContractStageLiving;
		}
		else if (DateTime.compareDatesWithoutTime(nCurrentDate, self._MoveOutDate) >= 0)
		{
			stage = ContractStageTermination;
		}	
	}



	///Helper functions
	function SimulateCurrentDate(EscrowContractState storage self, uint n) public
	{
		if (EnableSimulatedCurrentDate)
		{
			self._CurrentDate = n;
			//int stage = GetCurrentStage(self);
			//logEvent(stage, LogMessageInfo, self._CurrentDate, "SimulateCurrentDate was called.");	
		}
	}
	
	
	
	function GetCurrentDate(EscrowContractState storage self) public constant returns (uint nCurrentDate)
	{
		if (EnableSimulatedCurrentDate)
		{
			nCurrentDate = self._CurrentDate;
		}
		else
		{
			nCurrentDate = now;
		}	
	}

	function GetContractBalance(EscrowContractState storage self) public returns (uint res)
	{
	    res = self._Balance;
	}


	function splitBalanceAccordingToRatings(int balance, int tenantScore, int landlScore) public constant returns (int tenantBal, int landlBal)
	{
		if (tenantScore == landlScore) {
			//Just split in two 
			tenantBal = balance / 2;
			landlBal = balance / 2;
		}
		else if (tenantScore == 0)
		{
			tenantBal = 0;
			landlBal = balance;			
		}
		else if (landlScore == 0) {
			tenantBal = balance;
			landlBal = 0;
		}
		else if (tenantScore > landlScore) {			
			landlBal = ((landlScore * balance / 2) / tenantScore);
			tenantBal = balance - landlBal;			
		}
		else if (tenantScore < landlScore) {			
			tenantBal = ((tenantScore * balance / 2) / landlScore);
			landlBal = balance - tenantBal;			
		}		
	}

	function formatDate(uint dt) public constant returns (string strDate)
	{
		bytes32 b1;
		bytes32 b2;
		bytes32 b3;
		b1 = uintToBytes(uint(DateTime.getMonth(dt)));
		b2 = uintToBytes(uint(DateTime.getDay(dt)));
		b3 = uintToBytes(uint(DateTime.getYear(dt)));
		string memory s1;
		string memory s2;	
		string memory s3;
		s1 = bytes32ToString(b1);
		s2 = bytes32ToString(b2);
		s3 = bytes32ToString(b3);
		
		string memory strDate1 = strConcat(s1, "/", s2, "/");
		strDate = strConcat(strDate1, s3);			
	}
	

    function strConcat(string _a, string _b, string _c, string _d, string _e) internal constant returns (string){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }
    
    function strConcat(string _a, string _b, string _c, string _d) internal constant returns (string) {
        return strConcat(_a, _b, _c, _d, "");
    }
    
    function strConcat(string _a, string _b, string _c) internal constant returns (string) {
        return strConcat(_a, _b, _c, "", "");
    }
    
    function strConcat(string _a, string _b) internal constant returns (string) {
        return strConcat(_a, _b, "", "", "");
    } 
    
    function bytes32ToString(bytes32 x) internal constant returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    function bytes32ArrayToString(bytes32[] data) internal constant returns (string) {
        bytes memory bytesString = new bytes(data.length * 32);
        uint urlLength;
        for (uint i=0; i<data.length; i++) {
            for (uint j=0; j<32; j++) {
                byte char = byte(bytes32(uint(data[i]) * 2 ** (8 * j)));
                if (char != 0) {
                    bytesString[urlLength] = char;
                    urlLength += 1;
                }
            }
        }
        bytes memory bytesStringTrimmed = new bytes(urlLength);
        for (i=0; i<urlLength; i++) {
            bytesStringTrimmed[i] = bytesString[i];
        }
        return string(bytesStringTrimmed);
    }  
    
    
    function uintToBytes(uint v) internal constant returns (bytes32 ret) {
        if (v == 0) {
            ret = '0';
        }
        else {
            while (v > 0) {
                ret = bytes32(uint(ret) / (2 ** 8));
                ret |= bytes32(((v % 10) + 48) * 2 ** (8 * 31));
                v /= 10;
            }
        }
        return ret;
    }

    /// @dev Converts a numeric string to it's unsigned integer representation.
    /// @param v The string to be converted.
    function bytesToUInt(bytes32 v) internal constant returns (uint ret) {
        if (v == 0x0) {
            throw;
        }

        uint digit;

        for (uint i = 0; i < 32; i++) {
            digit = uint((uint(v) / (2 ** (8 * (31 - i)))) & 0xff);
            if (digit == 0) {
                break;
            }
            else if (digit < 48 || digit > 57) {
                throw;
            }
            ret *= 10;
            ret += (digit - 48);
        }
        return ret;
    }    


}