// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

error Unauthorized();

contract RPSGame {
    // GameState - INITIATED after inital game setup, RESPONDED after responder adds hash choice, WIN or DRAW after final scoring
    enum RPSGameState {INITIATED, RESPONDED, WIN, DRAW}
    
    // PlayerState - PENDING until they add hashed choice, PLAYED after adding hash choice, CHOICE_STORED once raw choice and random string are stored
    enum PlayerState {PENDING, PLAYED, CHOICE_STORED}
    
    // 0 before choices are stored, 1 for Rock, 2 for Paper, 3 for Scissors. Strings are stored only to generate comment with choice names
    string[4] choiceMap = ['None', 'Rock', 'Paper', 'Scissors'];
    
    struct RPSGameData {
        address initiator; // Address of the initiator
        PlayerState initiator_state; // State of the initiator
        bytes32 initiator_hash; // Hashed choice of the initiator
        uint8 initiator_choice; // Raw number of initiator's choice - 1 for Rock, 2 for Paper, 3 for Scissors
        string initiator_random_str; // Random string chosen by the initiator
        
	address responder; // Address of the responder
        PlayerState responder_state; // State of the responder
        bytes32 responder_hash; // Hashed choice of the responder
        uint8 responder_choice; // Raw number of responder's choice - 1 for Rock, 2 for Paper, 3 for Scissors
        string responder_random_str; // Random string chosen by the responder
                
        RPSGameState state; // Game State
        address winner; // Address of winner after completion. addresss(0) in case of draw
        string comment; // Comment specifying what happened in the game after completion
    }
    
    RPSGameData _gameData;
    
    // Initiator sets up the game and stores its hashed choice in the creation itself. Game and player states are adjusted accordingly
    constructor(address _initiator, address _responder, bytes32 _initiator_hash) {
        _gameData = RPSGameData({
                                    initiator: _initiator,
                                    initiator_state: PlayerState.PLAYED,
                                    initiator_hash: _initiator_hash, 
                                    initiator_choice: 0,
                                    initiator_random_str: '',
                                    responder: _responder, 
                                    responder_state: PlayerState.PENDING,
                                    responder_hash: 0, 
                                    responder_choice: 0,
                                    responder_random_str: '',
                                    state: RPSGameState.INITIATED,
                                    winner: address(0),
                                    comment: ''
                            });
    }
    
    // Responder stores their hashed choice. Game and player states are adjusted accordingly.
    function addResponse(bytes32 _responder_hash) public {
        require( _gameData.state == RPSGameState.INITIATED, "Game has not been initiated");
        _gameData.responder_hash = _responder_hash;
        _gameData.state = RPSGameState.RESPONDED;
        _gameData.responder_state = PlayerState.PLAYED;
    }
    
    // Initiator adds raw choice number and random string. If responder has already done the same, the game should process the completion execution
    function addInitiatorChoice(uint8 _choice, string memory _randomStr) public returns (bool) {
        require( _gameData.state == RPSGameState.RESPONDED, "Responder yet to acknowledged");
        _gameData.initiator_choice = _choice;
        _gameData.initiator_random_str = _randomStr;
        _gameData.initiator_state = PlayerState.CHOICE_STORED;
        if (_gameData.responder_state == PlayerState.CHOICE_STORED) {
            __validateAndExecute();
        }
        return true;
    }

    // Responder adds raw choice number and random string. If initiator has already done the same, the game should process the completion execution
    function addResponderChoice(uint8 _choice, string memory _randomStr) public returns (bool) {
        require( _gameData.state == RPSGameState.RESPONDED, "Responder yet to acknowledged");
        _gameData.responder_choice = _choice;
        _gameData.responder_random_str = _randomStr;
        _gameData.responder_state = PlayerState.CHOICE_STORED;
        if (_gameData.initiator_state == PlayerState.CHOICE_STORED) {
            __validateAndExecute();
        }
        return true;
    }
    
    // Core game logic to check raw choices against stored hashes, and then the actual choice comparison
    // Can be split into multiple functions internally
    function __validateAndExecute() private {
        bytes32 initiatorCalcHash = sha256(abi.encodePacked(choiceMap[_gameData.initiator_choice], '-', _gameData.initiator_random_str));
        bytes32 responderCalcHash = sha256(abi.encodePacked(choiceMap[_gameData.responder_choice], '-', _gameData.responder_random_str));
        bool initiatorAttempt = false;
        bool responderAttempt = false;
        
        if (initiatorCalcHash == _gameData.initiator_hash) {
            initiatorAttempt = true;
        }
        
        if (responderCalcHash == _gameData.responder_hash) {
            responderAttempt = true;
        }
        
        // Add logic to complete the game first based on attempt validation states, and then based on actual game logic if both attempts are validation
        // Comments can be set appropriately like 'Initator attempt invalid', or 'Scissor beats Paper', etc.
        if (( !initiatorAttempt && !responderAttempt ) || 
        ( _gameData.initiator_choice == 0 &&  _gameData.responder_choice == 0 ))  {
            _gameData.state = RPSGameState.DRAW;
            _gameData.comment = string(abi.encodePacked('Both initator and responder attempt invalid'));
        }
        else if ( !initiatorAttempt || _gameData.initiator_choice == 0 ) {
            _gameData.state = RPSGameState.WIN;
            _gameData.winner = _gameData.responder;
            _gameData.comment = string(abi.encodePacked('Initator attempt invalid'));
        }
        else if ( !responderAttempt ||_gameData.responder_choice == 0 ) {
            _gameData.state = RPSGameState.WIN;
            _gameData.winner = _gameData.initiator;
            _gameData.comment = string(abi.encodePacked('Responder attempt invalid'));
        }
        else if ( _gameData.initiator_choice ==  _gameData.responder_choice ) {
            _gameData.state = RPSGameState.DRAW;
            _gameData.comment = string(abi.encodePacked('Both initator and responder choice are same'));
        }
        else if (( _gameData.initiator_choice > 1 && _gameData.initiator_choice > _gameData.responder_choice ) || 
        ( _gameData.initiator_choice == 1 && _gameData.responder_choice == 3 )) {
            _gameData.state = RPSGameState.WIN;
            _gameData.winner = _gameData.initiator;
            _gameData.comment = string(abi.encodePacked(
                choiceMap[_gameData.initiator_choice], 
                ' beats ', 
                choiceMap[_gameData.responder_choice], 
                ', hence Initator won!'));
        }
        else {
            _gameData.state = RPSGameState.WIN;
            _gameData.winner = _gameData.responder;
            _gameData.comment = string(abi.encodePacked(
                choiceMap[_gameData.initiator_choice], 
                ' beats ', 
                choiceMap[_gameData.responder_choice], 
                ', hence Responder won!'));
        }
    }

    // string[4] choiceMap = ['None', 'Rock', 'Paper', 'Scissors'];
    // Returns the address of the winner, GameState (2 for WIN, 3 for DRAW), and the comment
    function getResult() public view returns (address, RPSGameState, string memory) {
        require( (_gameData.state != RPSGameState.INITIATED &&
        _gameData.state != RPSGameState.RESPONDED && 
        _gameData.initiator_state == PlayerState.CHOICE_STORED && 
        _gameData.responder_state == PlayerState.CHOICE_STORED ), "Game is not completed");
        return (_gameData.winner, _gameData.state, _gameData.comment);
    } 
    
}


contract RPSServer {
    // Mapping for each game instance with the first address being the initiator and internal key aaddress being the responder
    mapping(address => mapping(address => RPSGame)) _gameList;

    // modifier to check if the chosen choice is in acceptable range
    modifier isValidChoice(uint8 choice_value) {
        // Choice should be between 1 and 3
        require((choice_value > 0 && choice_value <= 3), "Choice should be in the range of 1 to 3");
        _;
    }

    // modifier to check if the address is zero
    modifier isValidAddress(address initiator, address responder) {
        // Checks initiator or responsder against zero address and 
        // whether initiator and responder are same
        require(initiator != address(0), "Initiator account is 0 address");
        require(responder != address(0), "Responder account is 0 address");
        require(initiator != responder, "Both initiator and responder cannot be same");
        _;
    }

    // Checks whether game has been initiated or not thru zero address validation
    function validGame(RPSGame game_instance) internal pure returns (bool){
        require( address(game_instance) != address(0) , "Game has not been initiated");
        return true;
    }
    
    // Initiator sets up the game and stores its hashed choice in the creation itself. New game created and appropriate function called    
    function initiateGame(address _responder, bytes32 _initiator_hash) public isValidAddress(msg.sender, _responder) {
        RPSGame game = new RPSGame(msg.sender, _responder, _initiator_hash);
        _gameList[msg.sender][_responder] = game;
    }

    // Responder stores their hashed choice. Appropriate RPSGame function called   
    function respond(address _initiator, bytes32 _responder_hash) public isValidAddress(_initiator, msg.sender) {
        RPSGame game = _gameList[_initiator][msg.sender];
        validGame(game);
        game.addResponse(_responder_hash);
    }

    // Initiator adds raw choice number and random string. Appropriate RPSGame function called  
    function addInitiatorChoice(address _responder, uint8 _choice, string memory _randomStr) 
    public isValidAddress(msg.sender, _responder) isValidChoice(_choice) returns (bool) {
        RPSGame game = _gameList[msg.sender][_responder];
        validGame(game);
        return game.addInitiatorChoice(_choice, _randomStr);
    }

    // Responder adds raw choice number and random string. Appropriate RPSGame function called
    function addResponderChoice(address _initiator, uint8 _choice, string memory _randomStr) 
    public isValidAddress(_initiator, msg.sender) isValidChoice(_choice) returns (bool) {
        RPSGame game = _gameList[_initiator][msg.sender];
        validGame(game);
        return game.addResponderChoice(_choice, _randomStr);
    }
    
    // Result details request by the initiator
    function getInitiatorResult(address _responder) public 
    isValidAddress(msg.sender, _responder) view returns (address, RPSGame.RPSGameState, string memory) {
        RPSGame game = _gameList[msg.sender][_responder];
        validGame(game);
        //require( address(game) != address(0) , "Game has not been initiated");
        return game.getResult();
    }

    // Result details request by the responder
    function getResponderResult(address _initiator) public 
    isValidAddress(_initiator, msg.sender) view returns (address, RPSGame.RPSGameState, string memory) {
        RPSGame game = _gameList[_initiator][msg.sender];
        validGame(game);
        // require( address(game) != address(0) , "Game has not been initiated");
        return game.getResult();
    }
}







