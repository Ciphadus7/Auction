//SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.5.0 <0.9.0;

///@author Ciphadus
///@title Auction Contract

contract AuctionCreator{
    Auction[] public auctions;

    function createAuction() public {               ///@dev enables another human to create their own auctions
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}


contract Auction{

    address payable public owner;       ///@dev initialize variablest
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;

    enum State {Started, Running, Ended, Cancelled}
    State public auctionState;

    uint public highestBindingBid;
    address payable public highestBidder;

    mapping(address => uint) public bids;

    uint bidIncrement;

    bool public ownerFinalized = false;

    constructor(address eoa){
        owner = payable (eoa);
        auctionState = State.Running;
        startBlock = block.number; //current block
        endBlock = startBlock + 3;
        ipfsHash = "";
        bidIncrement = 1000000000000000000;
    }
    

    ///@dev declaring function modifiers

    modifier notOwner(){
        require(msg.sender != owner);
        _;
    }

    modifier afterStart(){
        require(block.number >= startBlock);
        _;
    }

    modifier beforeEnd(){
        require(block.number <=endBlock);
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    ///@dev a helper pure function
    function min(uint a, uint b) pure internal returns(uint){
        if( a <= b){
            return a;
        }else{
            return b;
        }
    }



    ///@dev main function called to place a bid
    function placeBid() public payable notOwner afterStart beforeEnd{
        ///@dev to place a bid, the acution should be running
        require(auctionState == State.Running);
        ///@dev Minimum value allowed to send
        require(msg.value >= 100);

        uint currentBid = bids[msg.sender] + msg.value;
        ///@notice the currentBid should be more than the highestBindingBid
        ///otherwise there is nothing to do.
        require(currentBid > highestBindingBid);

        ///@dev updating the mapping variable
        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]){  ///@dev highestBidder remains unchanged
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        }else{ ///@dev highestBidder is another bidder
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable (msg.sender);
        }
    }

    ///@dev Only the owner can cancel the auction before the auction has ended.
    function cancelAuction() public onlyOwner{
        auctionState = State.Cancelled;

    }


    function finalizeAuction() public {
        ///@dev the action has been canclled or ended
        require(auctionState == State.Cancelled || block.number > endBlock);
        ///@dev only the owner or a bidder can finalize the auction.
        require(msg.sender == owner || bids[msg.sender] > 0);
        ///@dev the recipient will get the value
        address payable recipient;
        uint value;

        if(auctionState == State.Cancelled){  //acution was cancelled
            recipient = payable (msg.sender);
            value = bids[msg.sender];
        }else{    //auction ended not cancelled
            if(msg.sender == owner && ownerFinalized == false){    //this is the owner
                recipient = owner;
                value = highestBindingBid;
                ownerFinalized = true;
            }else{  //this is a bidder
                if(msg.sender == highestBidder){
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                }else{ //this is neither the owner nor the highestBidder
                    recipient = payable (msg.sender);
                    value = bids[msg.sender];
                }
            }
        }

        bids[recipient] = 0;        ///@dev resetting the bids of the recipient to avoid multiple transfers to the same recipient
        recipient.transfer(value);  ///@dev sends value to the recipient

    }

}
