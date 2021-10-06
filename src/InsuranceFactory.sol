pragma solidity >=0.4.4 <0.7.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./BasicOperation.sol";
import "./ERC20Basic.sol";

contract InsuranceFactory is BasicOperations {

    ERC20Basic private token;
    //  direccion del seguro
    address insuranceAddress;
    //  direcicon de la aseguradora
    address payable public insurerAddress;

    address[] clientAddressList;
    address[] laboratoryAddressList;
    string[] private serviceNameList;

    mapping(address => ClientStructure) public clientMapping;
    mapping(address => LaboratoryStruct) public laboratoryMapping;
    mapping(string => ServiceStruct) public serviceMapping;

    struct ClientStructure {
        address clientAddress;
        bool authorizationClient;
        address contractAddress;
    }

    struct ServiceStruct {
        string serviceName;
        uint servicePrice;
        bool serviceStatus;
    }

    struct LaboratoryStruct {
        address labContractAddress;
        bool labStatus;
    }


    constructor () public {
        token = new ERC20Basic(100);
        insuranceAddress = address(this);
        insurerAddress = msg.sender;
    }

    modifier onlyClients(address clientAddress) {
        isAuthorizedClient(clientAddress);
        _;
    }

    modifier onlyInsurance(address insuranceAddress) {
        require(insurerAddress == insuranceAddress, "Insurance address nor authorized");
        _;
    }

    modifier isAvailableClientAddress(address insurerAddress, address inputAddress) {
        require(clientMapping[inputAddress].authorizationClient == true && insurerAddress == inputAddress
            || insurerAddress == clientMapping[insurerAddress].clientAddress);
        _;
    }

    modifier onlyExecuteByHealthCenter(address healthCenterAddress) {
        require(healthCenterAddress == insurerAddress);
        _;
    }

    event buyTokenEvent(uint256);
    event serviceGivenEvent(address, string, uint256);
    event laboratoryCreateEvent(address, address);
    event clientCreateEvent(address, address);
    event deleteClientEvent(address);
    event serviceCreateEvent(string, uint256);
    event deleteServiceEvent(string);

    function isAuthorizedClient(address clientAddress) public view {
        require(clientMapping[clientAddress].authorizationClient == true, "Address client is not authorized");
    }

    function creatLaboratory() public {
        laboratoryAddressList.push(msg.sender);
        address labAddress = address(new Laboratory(msg.sender, insuranceAddress));
        LaboratoryStruct memory laboratoryStruct = LaboratoryStruct(labAddress, true);
        laboratoryMapping[msg.sender] = laboratoryStruct;
        emit laboratoryCreateEvent(msg.sender, labAddress);
    }

    function createClientContract() public {
        clientAddressList.push(msg.sender);
        address clientAddress = address(new ClientHealthRecord(msg.sender, token, insuranceAddress, insurerAddress));
        clientMapping[msg.sender] = ClientStructure(msg.sender, true, clientAddress);
        emit clientCreateEvent(msg.sender, clientAddress);
    }

    function laboratories() public view onlyExecuteByHealthCenter(msg.sender) returns (address[] memory) {
        return laboratoryAddressList;
    }

    function clients() public view onlyExecuteByHealthCenter(msg.sender) returns (address[] memory) {
        return clientAddressList;
    }

    function getHistoryClient(address clientAddress, address consultorAddress)
    public view isAvailableClientAddress(clientAddress, consultorAddress) returns (string memory) {
        string memory history = "";
        address clientContractAddress = clientMapping[clientAddress].contractAddress;
        for (uint i = 0; i < serviceNameList.length; i++) {
            if (serviceMapping[serviceNameList[i]].serviceStatus == true &&
                ClientHealthRecord(clientContractAddress).hasPracticeService(serviceNameList[i]) == true) {
                (string memory serviceName, uint256 servicePrice) =
                ClientHealthRecord(clientContractAddress).historyInsurer(serviceNameList[i]);
                history = string(abi.encodePacked(history, "(", serviceName, ", ", uintToString(servicePrice)));
            }
        }
        return history;
    }

    function deleteExistingClient(address clientAddress) public onlyExecuteByHealthCenter(msg.sender) {
        clientMapping[clientAddress].authorizationClient = false;
        ClientHealthRecord(clientMapping[clientAddress].contractAddress).deleteClient();
        emit deleteClientEvent(clientAddress);
    }

    function createNewService(string memory serviceName, uint256 servicePrice) public onlyExecuteByHealthCenter(msg.sender) {
        serviceMapping[serviceName] = ServiceStruct(serviceName, servicePrice, true);
        serviceNameList.push(serviceName);
        emit serviceCreateEvent(serviceName, servicePrice);
    }

    function deleteExistingService(string memory serviceName) public onlyExecuteByHealthCenter(msg.sender) {
        require(getStatusService(serviceName) == true, "Not fund service available with that name");
        serviceMapping[serviceName].serviceStatus = false;
        emit deleteServiceEvent(serviceName);
    }

    function getStatusService(string memory serviceName) public view returns (bool) {
        return serviceMapping[serviceName].serviceStatus;
    }

    function getPriceService(string memory serviceName) public view returns (uint256) {
        require(getStatusService(serviceName) == true, "Not fund service available with that name");
        return serviceMapping[serviceName].servicePrice;
    }

    function getAllAvailableService() public view returns (string[] memory) {
        string[] memory availableServiceList = new string[](serviceNameList.length);
        uint acumulator = 0;
        for (uint i = 0; i < serviceNameList.length; i++) {
            if (getStatusService(serviceNameList[i]) == true) {
                availableServiceList[acumulator] = serviceNameList[i];
                acumulator ++;
            }
        }
        return availableServiceList;
    }

    function buyTokens(address client, uint tokenNumber) public payable onlyInsurance(client) {
        uint256 balance = balanceOf();
        require(tokenNumber <= balance, "Can not buy that quantity of token");
        require(tokenNumber >= 0, "Can not buy negative quantity of token");
        token.transfer(msg.sender, tokenNumber);
        emit buyTokenEvent(tokenNumber);
    }

    function balanceOf() public view returns (uint256){
        return (token.balanceOf(insuranceAddress));
    }

    function generateNewToken(uint tokenNumber) public onlyExecuteByHealthCenter(msg.sender) {
        token.increaseTotalSupply(tokenNumber);
    }
}

contract ClientHealthRecord is BasicOperations {

    enum Status {
        createdNew, deleteOne
    }

    struct Owner {
        address ownerAddress;
        uint ownerBalance;
        Status ownerStatus;
        IERC20 ownerTokens;
        address insuranceAddress;
        address insurerAddress;
    }

    struct RequestServices {
        string serviceName;
        uint256 servicePrice;
        bool serviceStatus;
    }

    struct RequestServiceLaboratory {
        string serviceName;
        uint256 servicePrice;
        address laboratoryAddress;
    }

    mapping(string => RequestServices) historyClientMapping;
    RequestServiceLaboratory[] historyRequestLabList;

    Owner propietary;

    constructor (address owner, IERC20 token, address insuranceAddress, address payable insurerAddress) public {
        propietary.ownerAddress = owner;
        propietary.ownerBalance = 0;
        propietary.ownerStatus = Status.createdNew;
        propietary.ownerTokens = token;
        propietary.insuranceAddress = insuranceAddress;
        propietary.insurerAddress = insurerAddress;
    }

    event selfDestructEvent(address);
    event retrieveTokensEvent(address, uint256);
    event payedServiceEvent(address, string, uint256);
    event requestServiceToLab(address, address, string);

    modifier onlyExecuteByPropietary(address ownerAddress) {
        require(ownerAddress == propietary.ownerAddress, "Do not have permission");
        _;
    }

    modifier onlyClients(address clientAddress) {
        require(clientAddress == propietary.ownerAddress);
        _;
    }

    function historyInsurerLab() public view returns (RequestServiceLaboratory[] memory) {
        return historyRequestLabList;
    }

    function historyInsurer(string memory serviceName) public view returns (string memory, uint) {
        return (historyClientMapping[serviceName].serviceName, historyClientMapping[serviceName].servicePrice);
    }

    function hasPracticeService(string memory serviceName) public view returns (bool) {
        return historyClientMapping[serviceName].serviceStatus;
    }

    function deleteClient() public onlyExecuteByPropietary(msg.sender) {
        emit selfDestructEvent(msg.sender);
        selfdestruct(msg.sender);
    }

    function buyToken(uint tokenNumber) public payable onlyExecuteByPropietary(msg.sender) {
        require(tokenNumber >= 0, "Can not buy negative quantity of token");
        uint tokenCost = tokenPriceToEther(tokenNumber);
        require(msg.value >= tokenCost, "Need to buy more eht");
        uint returnValue = msg.value - tokenCost;
        msg.sender.transfer(returnValue);
        InsuranceFactory(propietary.insuranceAddress).buyTokens(msg.sender, tokenNumber);
    }

    function balanceOf() public view onlyExecuteByPropietary(msg.sender) returns (uint256) {
        return (propietary.ownerTokens.balanceOf(address(this)));
    }

    function retrieveTokenToInsurance(uint tokenNumber) public payable onlyExecuteByPropietary(msg.sender) {
        require(tokenNumber >= 0, "Can not retrieve negative quantity of token");
        require(tokenNumber <= balanceOf(), "Do not have that quantity of tokens to retrieve");
        propietary.ownerTokens.transfer(propietary.insuranceAddress, tokenNumber);
        msg.sender.transfer(tokenPriceToEther(tokenNumber));
        emit retrieveTokensEvent(msg.sender, tokenNumber);
    }

    function requestService(string memory serviceName) public onlyClients(msg.sender) {
        require(InsuranceFactory(propietary.insuranceAddress).getStatusService(serviceName) == true, "Not available service");
        uint256 payToken = InsuranceFactory(propietary.insuranceAddress).getPriceService(serviceName);
        require(payToken <= balanceOf(), "Need to buy more tokens for this operation");
        propietary.ownerTokens.transfer(propietary.insuranceAddress, payToken);
        historyClientMapping[serviceName] = RequestServices(serviceName, payToken, true);
        emit payedServiceEvent(msg.sender, serviceName, payToken);
    }

    function requestServiceFromLab(address labAddress, string memory serviceName) public payable onlyClients(msg.sender) {
        Laboratory laboratory = Laboratory(labAddress);
        require(msg.value == laboratory.getServicePrice(serviceName) * 1 ether, "Invalid operation");
        laboratory.giveServiceToCLient(msg.sender, serviceName);
        payable(laboratory.labAddress()).transfer(laboratory.getServicePrice(serviceName) * 1 ether);
        historyRequestLabList.push(RequestServiceLaboratory(serviceName, laboratory.getServicePrice(serviceName), labAddress));
        emit requestServiceToLab(labAddress, msg.sender, serviceName);
    }
}

contract Laboratory is BasicOperations {

    address public insuranceContractAddress;
    address public labAddress;
    address[] public requestService;
    string[] serviceAvailableFromLab;

    mapping(address => string) public requestServiceMapping;
    mapping(address => ServiceResult) resultServiceLabMapping;
    mapping(string => AvailableServiceFromLab) public availableServiceLabMapping;

    constructor(address account, address insuranceContractAddress) public {
        labAddress = account;
        insuranceContractAddress = insuranceContractAddress;
    }

    event serviceWorking(string, uint);
    event emitService(address, string);

    struct ServiceResult {
        string diagnosticService;
        string ipfsCode;
    }

    struct AvailableServiceFromLab {
        string serviceName;
        uint256 servicePrice;
        bool serviceStatus;
    }

    modifier onlyExecuteByLaboratory(address labAddress) {
        require(labAddress == labAddress, "Do not have permission to execute");
        _;
    }

    function getAvailableService() public view returns (string[] memory) {
        return serviceAvailableFromLab;
    }

    function getServicePrice(string memory serviceName) public view returns (uint256) {
        return availableServiceLabMapping[serviceName].servicePrice;
    }

    function giveServiceToCLient(address clientAddress, string memory serviceName) public {
        InsuranceFactory insuranceFactory = InsuranceFactory(insuranceContractAddress);
        insuranceFactory.isAuthorizedClient(clientAddress);
        require(availableServiceLabMapping[serviceName].serviceStatus == true, "Service not available");
        requestServiceMapping[clientAddress] = serviceName;
        requestService.push(clientAddress);
        emit emitService(clientAddress, serviceName);
    }

    function createNewServiceInLab(string memory serviceName, uint servicePrice) public onlyExecuteByLaboratory(msg.sender) {
        availableServiceLabMapping[serviceName] = AvailableServiceFromLab(serviceName, servicePrice, true);
        serviceAvailableFromLab.push(serviceName);
        serviceWorking(serviceName, servicePrice);
    }

    function retrieveResults(address clientAddress,
        string memory diagnostic, string memory ipfsCode) public onlyExecuteByLaboratory(msg.sender) {
        resultServiceLabMapping[clientAddress] = ServiceResult(diagnostic, ipfsCode);
    }

    function getResults(address clientAddress) public view returns (string memory diagnostic, string memory ipfsCode) {
        diagnostic = resultServiceLabMapping[clientAddress].diagnosticService;
        ipfsCode = resultServiceLabMapping[clientAddress].ipfsCode;
    }
}