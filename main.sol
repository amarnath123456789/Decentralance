// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
 
contract GigPlatform is ERC721Enumerable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
 
    Counters.Counter private _gigIds;
    Counters.Counter private _tokenIds;
 
    enum GigStatus { Open, InProgress, Completed }
    enum BadgeType { Experience, Excellence, Loyalty, Trustworthy }
 
    struct Gig {
        address payable client;
        address payable freelancer;
        uint256 budget;
        string description;
        string review;
        GigStatus status;
        uint8 rating; // out of 10
    }
 
    struct User {
        uint256 totalGigs;
        uint8 reviewStreak; // Count of consecutive good reviews (>=8 out of 10)
        mapping(BadgeType => bool) badges;
    }
 
    mapping(uint256 => Gig) public gigs;
    mapping(address => User) public users;
 
    uint256 public constant REVIEW_STREAK_THRESHOLD = 5; 
    uint256 public constant GIG_THRESHOLD = 10;
 
    event GigPosted(address indexed client, uint256 gigId);
    event FreelancerHired(uint256 gigId, address indexed freelancer);
    event GigCompleted(uint256 gigId);
    event BadgeMinted(address indexed recipient, BadgeType badgeType, uint256 tokenId);
 
    constructor() ERC721("GigPlatformBadge", "GPB") {}
 
    function postGig(string memory _description, uint256 _budget) external returns (uint256) {
        _gigIds.increment();
        uint256 gigId = _gigIds.current();
 
        gigs[gigId] = Gig({
            client: payable(msg.sender),
            freelancer: payable(address(0)),
            budget: _budget,
            description: _description,
            review: "",
            status: GigStatus.Open,
            rating: 0
        });
 
        emit GigPosted(msg.sender, gigId);
        return gigId;
    }
 
    function hireFreelancer(uint256 _gigId, address payable _freelancer) external {
        Gig storage gig = gigs[_gigId];
        require(msg.sender == gig.client, "Only the client can hire a freelancer.");
        require(gig.status == GigStatus.Open, "Gig is not open for hiring.");
 
        gig.freelancer = _freelancer;
        gig.status = GigStatus.InProgress;
 
        emit FreelancerHired(_gigId, _freelancer);
    }
 
    function completeAndReviewGig(uint256 _gigId, uint8 _rating, string memory _review) external {
        require(_rating <= 10, "Rating should be out of 10.");
 
        Gig storage gig = gigs[_gigId];
        require(msg.sender == gig.client, "Only the client can rate and complete the gig.");
        require(gig.status == GigStatus.InProgress, "Gig is not in progress.");
 
        gig.rating = _rating;
        gig.review = _review;
        gig.status = GigStatus.Completed;
        gig.freelancer.transfer(gig.budget);
 
        User storage freelancer = users[gig.freelancer];
        User storage client = users[gig.client];
 
        freelancer.totalGigs = freelancer.totalGigs.add(1);
        client.totalGigs = client.totalGigs.add(1);
 
        if (_rating >= 8) {
            freelancer.reviewStreak = freelancer.reviewStreak.add(1);
        } else {
            freelancer.reviewStreak = 0;
        }
 
        _checkAndMintBadges(gig.freelancer, gig.client);
 
        emit GigCompleted(_gigId);
    }
 
    function _checkAndMintBadges(address _freelancer, address _client) internal {
        User storage freelancer = users[_freelancer];
        User storage client = users[_client];
 
        if (freelancer.totalGigs >= GIG_THRESHOLD && !freelancer.badges[BadgeType.Experience]) {
            _mintBadge(_freelancer, BadgeType.Experience);
            freelancer.badges[BadgeType.Experience] = true;
        }
 
        if (freelancer.reviewStreak >= REVIEW_STREAK_THRESHOLD && !freelancer.badges[BadgeType.Excellence]) {
            _mintBadge(_freelancer, BadgeType.Excellence);
            freelancer.badges[BadgeType.Excellence] = true;
        }
 
        if (client.totalGigs >= GIG_THRESHOLD && !client.badges[BadgeType.Loyalty]) {
            _mintBadge(_client, BadgeType.Loyalty);
            client.badges[BadgeType.Loyalty] = true;
        }
 
        // Assuming that trustworthy clients consistently give honest and reasonable feedback.
        if (client.totalGigs >= REVIEW_STREAK_THRESHOLD && !client.badges[BadgeType.Trustworthy]) {
            _mintBadge(_client, BadgeType.Trustworthy);
            client.badges[BadgeType.Trustworthy] = true;
        }
    }
 
    function _mintBadge(address _recipient, BadgeType _badgeType) internal {
        _tokenIds.increment();
        uint256 newBadgeId = _tokenIds.current();
        _safeMint(_recipient, newBadgeId);
        emit BadgeMinted(_recipient, _badgeType, newBadgeId);
    }
}
