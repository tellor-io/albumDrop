// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

// import "./UsingTellor.sol";
// import "./SampleUsingTellor.sol";
// import "./TellorPlayground.sol";

import "usingtellor/contracts/UsingTellor.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

// goal = users can launch a campaign staking their goal (amt of tokens they want to raise)
// startAt = time when the campaign will start
// endAt = time when the campaign will end 

contract CrowdFund is UsingTellor {
    event Launch(
        uint256 id,
        address indexed creator,
        uint256 goal, 
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(uint256 id); // creator of campaign can cancel if campaign has not yet started
    event Pledge(uint256 indexed id, address indexed caller, uint256 amount); // user can pedge to a campaign
    event Unpledge(uint256 indexed id, address indexed caller, uint256 amount); // user can change their mind and unpledge
    event Claim(uint256 id); // if goal is met, campaign creator can claim what was pledged
    event Refund(uint256 id, address indexed caller, uint256 amount); // if goal is not met, users can get a refund of their pledged funds

    struct Campaign {
        
        address creator; // Creator of campaign
        uint256 goal; // Amount of tokens to raise
        uint256 pledged; // Total amount pledged
        uint32 startAt; // Timestamp of start of campaign
        uint32 endAt; // Timestamp of end of campaign
        bool claimed; // True if goal was reached and creator has claimed the tokens.
    }

    IERC20 public immutable token;
    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint256 public count;
    // Mapping from id to Campaign (key => value)
    mapping(uint256 => Campaign) public campaigns;
    // Mapping from campaign id => pledger => amount pledged
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;

    constructor(address payable _tellorAddress, address _token)
        UsingTellor(_tellorAddress)
    {
        token = IERC20(_token);
    }

    function launch(
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external {
        require(_startAt >= block.timestamp, "start at < now");
        require(_endAt >= _startAt, "end at < start at");
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function cancel(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "not creator");
        require(block.timestamp < campaign.startAt, "started");

        delete campaigns[_id];
        emit Cancel(_id);
    }

    function pledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "not started");
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint256 _id) external {
        Campaign storage campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "not creator");
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged >= campaign.goal, "pledged < goal");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.pledged);

        emit Claim(_id);
    }

    // Tellor function for establishing album drop. Specify the _id# below
    function didHappen(uint256 _id) public {
        bool _a;
        address _addy;
        bytes32 _queryId = keccak256(abi.encode("albumDrop", abi.encode(_id)));

        (bool _ifRetrieve, bytes memory _val, ) = getCurrentValue(_queryId);
        require(_ifRetrieve, "must get data to execute vote");

        // decode the bytes and transfer the tokens
        (_a, _addy) = abi.decode(_val, (bool, address));
        if (_a) {
            // transferTokens(_addy);
        }

        // IERC20(_token).transfer(owner, (_cumulativeReward * fees) / 1000);
    }

    function refund(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged < campaign.goal, "pledged >= goal");

        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
