// SPDX-License-Identifier: UNLICENSED
// SlotMachin made by PIH
pragma solidity ^0.8.0;

contract SlotMachine {
    address public owner;
    address[] public players;
    uint256 public playerCount;

    uint256 public minBetAmount = 0.1 ether;
    uint256 public jacpotBalance = 0 ether;

    uint256 private node = 0;

    struct SpinRecord {
        uint256 betAmount; // 배팅 금액
        uint256[] hand; // 포커 패
        string pokerResult; // 포커 결과
        uint256 resultAmount; // 최종 금액
    }
    mapping(address => SpinRecord[]) public playerList;
    event SpinResult(address indexed player, uint256 betAmount, uint256[] hand, string pokerResult, uint256 resultAmount);


    // 계약이 생성되었을 때
    constructor() {
        owner = msg.sender;
    }

    // 계약이 이더를 받았을 때
    receive() external payable {
        // 플레이어 수 업데이트
        if (playerList[msg.sender].length == 0) {
            players.push(msg.sender);
            playerCount++;
        }
        // 슬롯머신 시작
        if (msg.sender != owner) {
            node = 0;
            start();
        }
    }

    // 슬롯머신 시작 함수
    function start() public payable {
        require(msg.value >= minBetAmount, "Minimum bet amount not met");

        uint256 userBalance = msg.value;
        jacpotBalance += userBalance / 10; // 배팅 금액의 10%를 잭팟에 누적

        uint256[] memory hand = new uint256[](5);
        hand = drawHand(); // 5개 숫자 드로우 (1~13)
        string memory pokerResult = checkPokerHand(hand); // 포커 판별

        uint256 winBalance;
        bool isJacpot = false;
        if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("Four of a Kind"))) {
            winBalance = userBalance * 8; // 0.024%
            isJacpot = true;
        }
        else if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("Full House"))) {
            winBalance = userBalance * 4; // 0.144%
        }
        else if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("Straight"))) {
            winBalance = userBalance * 2; // 0.39%
        }
        else if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("Three of a Kind"))) {
            winBalance = userBalance + (userBalance / 2); // 2.11%
        }
        else if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("Two Pair"))) {
            winBalance = userBalance; // 4.75%
        }
        else if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("One Pair"))) {
            winBalance = userBalance / 2; // 42.3%
        }
        else if(keccak256(abi.encodePacked(pokerResult)) == keccak256(abi.encodePacked("No Pair"))) {
            winBalance = 0; // 50.1%
        }

        if (isJacpot && address(this).balance < winBalance + jacpotBalance) {
            jacpotBalance -= (address(this).balance - winBalance);
            winBalance = address(this).balance;
        }
        else if (isJacpot && address(this).balance >= winBalance + jacpotBalance) {
            winBalance += jacpotBalance;
            jacpotBalance = 0;
        }
        else if (!isJacpot && address(this).balance < winBalance) {
            winBalance = address(this).balance;
        }
        payable(msg.sender).transfer(winBalance);
        emit SpinResult(msg.sender, userBalance / 1 ether, hand, pokerResult, winBalance / 1 ether);

        // 플레이어의 기록 저장
        SpinRecord memory spinRecord = SpinRecord(userBalance / 1 ether, hand, pokerResult, winBalance / 1 ether);
        playerList[msg.sender].push(spinRecord);
    }

    // 랜덤 함수
    function random() public view returns (uint256){
        return uint256(keccak256(abi.encodePacked(owner, block.timestamp, node))) % 13 + 1;
    }
    function drawHand() public returns (uint256[] memory){
        uint256[] memory draw = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            draw[i] = random();
            node++;
        }
        return draw;
    }

    // 포커 패턴을 판별하는 함수
    function checkPokerHand(uint256[] memory _hand) public pure returns (string memory) {
        uint[14] memory counts; // counts[0]은 사용하지 않음
        for(uint i = 0; i < 5; i++) {
            counts[_hand[i]]++;
        }

        bool hasPair = false;
        bool hasTwoPair = false;
        bool hasThreeOfAKind = false;
        bool hasFourOfAKind = false;
        bool hasFullHouse = false;
        bool hasStraight = false;

        for(uint i = 1; i <= 13; i++) {
            if(counts[i] == 2) {
                if(hasPair) {
                    hasTwoPair = true;
                } else {
                    hasPair = true;
                }
            } else if(counts[i] == 3) {
                if(hasPair) {
                    hasFullHouse = true;
                } else {
                    hasThreeOfAKind = true;
                }
            } else if(counts[i] >= 4) {
                hasFourOfAKind = true;
            }
        }

        _hand = sortArray(_hand);
        for (uint256 i = 0; i < _hand.length - 1; i++) {
            if (_hand[i] + 1 != _hand[i + 1]) {
                hasStraight = false;
                break;
            }
            if(i == _hand.length - 1) {
                hasStraight = true;
            }
        }
        if(_hand[0] == 1 && _hand[1] == 10 && _hand[2] == 11 && _hand[3] == 12 && _hand[4] == 13) hasStraight = true;
        else if(_hand[0] == 1 && _hand[1] == 2 && _hand[2] == 11 && _hand[3] == 12 && _hand[4] == 13) hasStraight = true;
        else if(_hand[0] == 1 && _hand[1] == 2 && _hand[2] == 3 && _hand[3] == 12 && _hand[4] == 13) hasStraight = true;
        else if(_hand[0] == 1 && _hand[1] == 2 && _hand[2] == 3 && _hand[3] == 4 && _hand[4] == 13) hasStraight = true;

        if(hasFourOfAKind) {
            return "Four of a Kind";
        } else if(hasFullHouse) {
            return "Full House";
        } else if(hasStraight) {
            return "Straight";
        } else if(hasThreeOfAKind) {
            return "Three of a Kind";
        } else if(hasTwoPair) {
            return "Two Pair";
        } else if(hasPair) {
            return "One Pair";
        } else {
            return "No Pair";
        }
    }
    // 오름차순 정렬
    function sortArray(uint256[] memory _array) internal pure returns (uint256[] memory) {
        uint256[] memory sortedArray = _array;

        for (uint256 i = 0; i < sortedArray.length; i++) {
            for (uint256 j = i + 1; j < sortedArray.length; j++) {
                if (sortedArray[i] > sortedArray[j]) {
                    uint256 temp = sortedArray[i];
                    sortedArray[i] = sortedArray[j];
                    sortedArray[j] = temp;
                }
            }
        }

        return sortedArray;
    }

    // 최소 배팅 금액 설정
    function setMinBetAmount(uint256 _minBetAmount) external {
        require(msg.sender == owner, "Only owner can set min bet amount");
        minBetAmount = _minBetAmount;
    }

    // 슬롯머신의 현재 잔액 확인
    function getContractBalance() external view returns (uint256) {
        return address(this).balance / 1 ether;
    }

    // 슬롯머신의 잔액 출금
    function withdrawSome(uint256 amount) external {
        require(msg.sender == owner, "Only owner can withdraw");
        require(amount * 1 ether < address(this).balance, "The withdrawal amount is higher than the balance.");
        payable(owner).transfer(amount * 1 ether);
    }
    function withdrawAll() external {
        require(msg.sender == owner, "Only owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }

    // 플레이어의 스핀 기록 조회
    function getPlayerSpinRecord(address player) external view returns (SpinRecord[] memory) {
        return playerList[player];
    }
    // 플레이어의 상위 5개 스핀 기록 조회
    function getTopRecordsForPlayers(address player) public view returns (SpinRecord[] memory) {
        SpinRecord[] memory allRecords = playerList[player];
        uint256 numRecords = allRecords.length;
        if (numRecords <= 5) {
            return allRecords;
        } else {
            // resultAmount를 기준으로 내림차순으로 정렬
            for (uint256 i = 0; i < numRecords; i++) {
                for (uint256 j = i + 1; j < numRecords; j++) {
                    if (allRecords[i].resultAmount < allRecords[j].resultAmount) {
                        SpinRecord memory temp = allRecords[i];
                        allRecords[i] = allRecords[j];
                        allRecords[j] = temp;
                    }
                }
            }
            // 상위 5개의 기록만을 선택하여 반환
            SpinRecord[] memory topRecords = new SpinRecord[](5);
            for (uint256 i = 0; i < 5; i++) {
                topRecords[i] = allRecords[i];
            }
            return topRecords;
        }
    }
    // 모든 플레이어의 상위 5개 스핀 기록 조회
    function getTopRecordsForAllPlayers() external view returns (SpinRecord[] memory) {
        // 모든 플레이어의 상위 5개 기록을 모으기 위한 배열
        SpinRecord[] memory allTopRecords;

        // 모든 플레이어의 상위 5개 기록을 모으기
        for (uint256 i = 0; i < playerCount; i++) {
            address playerAddress = players[i];
            SpinRecord[] memory playerTopRecords = getTopRecordsForPlayers(playerAddress);
            for (uint256 j = 0; j < playerTopRecords.length; j++) {
                allTopRecords = appendRecord(allTopRecords, playerTopRecords[j]);
            }
        }

        // 상위 5개 기록을 찾기 위해 정렬
        quickSort(allTopRecords, int(0), int(allTopRecords.length - 1));

        // 상위 5개 기록 반환
        uint256 recordsToReturn = allTopRecords.length < 5 ? allTopRecords.length : 5;
        SpinRecord[] memory topRecords = new SpinRecord[](recordsToReturn);
        for (uint256 k = 0; k < recordsToReturn; k++) {
            topRecords[k] = allTopRecords[k];
        }
        return topRecords;
    }

    // 두 SpinRecord 배열을 합치는 함수
    function appendRecord(SpinRecord[] memory arr1, SpinRecord memory record) internal pure returns (SpinRecord[] memory) {
        SpinRecord[] memory newArray = new SpinRecord[](arr1.length + 1);
        for (uint256 i = 0; i < arr1.length; i++) {
            newArray[i] = arr1[i];
        }
        newArray[arr1.length] = record;
        return newArray;
    }

    // 빠른 정렬 알고리즘을 사용한 정렬 함수
    function quickSort(SpinRecord[] memory arr, int left, int right) internal pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)].resultAmount;
        while (i <= j) {
            while (arr[uint(i)].resultAmount > pivot) i++;
            while (pivot > arr[uint(j)].resultAmount) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }
}
