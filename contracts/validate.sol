// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.7;
// import "openzeppelin-solidity/contracts/utils/cryptography/MerkleProof.sol";
// import "./stakeAddress.sol";
// contract Validation {
//     uint256 internal constant maxBTCAddressSatoshi = 0;
//     bytes32 internal constant merkleTreeRoot = 0x4e831acb4223b66de3b3d2e54a2edeefb0de3d7916e2886a4b134d9764d41bec;
//     uint8 internal constant CLAIM_FLAG_MSG_PREFIX_OLD = 1 << 0;
//     uint8 internal constant CLAIM_FLAG_BTC_ADDR_COMPRESSED = 1 << 1;
//     uint8 internal constant CLAIM_FLAG_BTC_ADDR_P2WPKH_IN_P2SH = 1 << 2;
//     uint8 internal constant CLAIM_FLAG_BTC_ADDR_BECH32 = 1 << 3;
//     uint8 internal constant CLAIM_FLAG_ETH_ADDR_LOWERCASE = 1 << 4;
//     uint8 internal constant ETH_ADDRESS_BYTE_LEN = 20;
//     uint8 internal constant ETH_ADDRESS_HEX_LEN = ETH_ADDRESS_BYTE_LEN * 2;

//     uint8 internal constant CLAIM_PARAM_HASH_BYTE_LEN = 12;
//     uint8 internal constant CLAIM_PARAM_HASH_HEX_LEN = CLAIM_PARAM_HASH_BYTE_LEN * 2;

//     uint8 internal constant BITCOIN_SIG_PREFIX_LEN = 24;
//     bytes24 internal constant BITCOIN_SIG_PREFIX_STR = "Bitcoin Signed Message:\n";

//     bytes internal constant STD_CLAIM_PREFIX_STR = "Claim_HEX_to_0x";
//     bytes internal constant OLD_CLAIM_PREFIX_STR = "Claim_BitcoinHEX_to_0x";
//     bytes16 internal constant HEX_DIGITS = "0123456789abcdef";
//     uint256 internal constant MERKLE_LEAF_SATOSHI_SIZE = 45;
//     uint256 internal constant MERKLE_LEAF_FILL_SIZE = 256 - 160 - MERKLE_LEAF_SATOSHI_SIZE;
//     uint256 internal constant MERKLE_LEAF_FILL_BASE = (1 << MERKLE_LEAF_FILL_SIZE) - 1;
//     uint256 internal constant MERKLE_LEAF_FILL_MASK = MERKLE_LEAF_FILL_BASE << MERKLE_LEAF_SATOSHI_SIZE;
//     mapping(bytes20 => bool) public btcAddressClaimsValid;

//     TestPTP mainContract;

//     constructor(address contractAddress)  {
//         mainContract = TestPTP(contractAddress);
//     }

//     function createFreeStake(
//         string memory btcAddress2, 
//         uint balance2,
//         address refererAddress,
//         bytes32[] calldata proof,
//         bytes32 pubKeyX,
//         bytes32 pubKeyY,
//         uint8 claimFlags,
//         uint8 v,
//         bytes32 r,
//         bytes32 s
//         ) external {
//         require(balance2 > 0, 'lowBalance');
//         address ad = refererAddress;
//         string memory btcAddress = btcAddress2;
//         uint balance = balance2;
//         btcAddressClaim(balance2, proof, msg.sender, pubKeyX, pubKeyY, claimFlags, v, r, s, 365,ad); 
//         mainContract.distributeFreeStake(msg.sender,btcAddress,balance, ad);             
//     }


//     function pubKeyToEthAddress(bytes32 pubKeyX, bytes32 pubKeyY)
//         public
//         pure
//         returns (address)
//     {
//         return address(uint160(uint256(keccak256(abi.encodePacked(pubKeyX, pubKeyY)))));
//     }

//     function _hash256(bytes memory data)
//         private
//         pure
//         returns (bytes32)
//     {
//         return sha256(abi.encodePacked(sha256(data)));
//     }

//     function _hexStringFromData(bytes memory hexStr, bytes32 data, uint256 dataLen)
//         private
//         pure
//     {
//         uint256 offset = 0;

//         for (uint256 i = 0; i < dataLen; i++) {
//             uint8 b = uint8(data[i]);

//             hexStr[offset++] = HEX_DIGITS[b >> 4];
//             hexStr[offset++] = HEX_DIGITS[b & 0x0f];
//         }
//     }

//     function _addressStringChecksumChar(bytes memory addrStr, uint256 offset, uint8 hashNybble)
//         private
//         pure
//     {
//         bytes1 ch = addrStr[offset];

//         if (ch >= "a" && hashNybble >= 8) {
//             addrStr[offset] = ch ^ 0x20;
//         }
//     }

//     function _addressStringCreate(address addr, bool includeAddrChecksum)
//         private
//         pure
//         returns (bytes memory addrStr)
//     {
//         addrStr = new bytes(ETH_ADDRESS_HEX_LEN);
//         _hexStringFromData(addrStr, bytes32(bytes20(addr)), ETH_ADDRESS_BYTE_LEN);

//         if (includeAddrChecksum) {
//             bytes32 addrStrHash = keccak256(addrStr);

//             uint256 offset = 0;

//             for (uint256 i = 0; i < ETH_ADDRESS_BYTE_LEN; i++) {
//                 uint8 b = uint8(addrStrHash[i]);

//                 _addressStringChecksumChar(addrStr, offset++, b >> 4);
//                 _addressStringChecksumChar(addrStr, offset++, b & 0x0f);
//             }
//         }

//         return addrStr;
//     }

//     function _claimMessageCreate(address claimToAddr, bytes32 claimParamHash, uint8 claimFlags)
//         private
//         pure
//         returns (bytes memory)
//     {
//         bytes memory prefixStr = (claimFlags & CLAIM_FLAG_MSG_PREFIX_OLD) != 0
//             ? OLD_CLAIM_PREFIX_STR
//             : STD_CLAIM_PREFIX_STR;

//         bool includeAddrChecksum = (claimFlags & CLAIM_FLAG_ETH_ADDR_LOWERCASE) == 0;

//         bytes memory addrStr = _addressStringCreate(claimToAddr, includeAddrChecksum);

//         if (claimParamHash == 0) {
//             return abi.encodePacked(
//                 BITCOIN_SIG_PREFIX_LEN,
//                 BITCOIN_SIG_PREFIX_STR,
//                 uint8(prefixStr.length) + ETH_ADDRESS_HEX_LEN,
//                 prefixStr,
//                 addrStr
//             );
//         }

//         bytes memory claimParamHashStr = new bytes(CLAIM_PARAM_HASH_HEX_LEN);

//         _hexStringFromData(claimParamHashStr, claimParamHash, CLAIM_PARAM_HASH_BYTE_LEN);

//         return abi.encodePacked(
//             BITCOIN_SIG_PREFIX_LEN,
//             BITCOIN_SIG_PREFIX_STR,
//             uint8(prefixStr.length) + ETH_ADDRESS_HEX_LEN + 1 + CLAIM_PARAM_HASH_HEX_LEN,
//             prefixStr,
//             addrStr,
//             "_",
//             claimParamHashStr    );
//     }

//     function claimMessageMatchesSignature(
//         address claimToAddr,
//         bytes32 claimParamHash,
//         bytes32 pubKeyX,
//         bytes32 pubKeyY,
//         uint8 claimFlags,
//         uint8 v,
//         bytes32 r,
//         bytes32 s
//     )
//         public
//         pure
//         returns (bool)
//     {
//         require(v >= 27 && v <= 30, "HEX: v invalid");

//         /*
//             ecrecover() returns an Eth address rather than a public key, so
//             we must do the same to compare.
//         */
//         address pubKeyEthAddr = pubKeyToEthAddress(pubKeyX, pubKeyY);

//         /* Create and hash the claim message text */
//         bytes32 messageHash = _hash256(
//             _claimMessageCreate(claimToAddr, claimParamHash, claimFlags)
//         );

//         /* Verify the public key */
//         return ecrecover(messageHash, v, r, s) == pubKeyEthAddr;
//     }

//     function _hash160(bytes memory data)
//         private
//         pure
//         returns (bytes20)
//     {
//         return ripemd160(abi.encodePacked(sha256(data)));
//     }

//     function pubKeyToBtcAddress(bytes32 pubKeyX, bytes32 pubKeyY, uint8 claimFlags)
//         public
//         pure
//         returns (bytes20)
//     {
//         /*
//             Helpful references:
//              - https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
//              - https://github.com/cryptocoinjs/ecurve/blob/master/lib/point.js
//         */
//         uint8 startingByte;
//         bytes memory pubKey;
//         bool compressed = (claimFlags & CLAIM_FLAG_BTC_ADDR_COMPRESSED) != 0;
//         bool nested = (claimFlags & CLAIM_FLAG_BTC_ADDR_P2WPKH_IN_P2SH) != 0;
//         bool bech32 = (claimFlags & CLAIM_FLAG_BTC_ADDR_BECH32) != 0;

//         if (compressed) {
//             /* Compressed public key format */
//             require(!(nested && bech32), "HEX: claimFlags invalid");

//             startingByte = (pubKeyY[31] & 0x01) == 0 ? 0x02 : 0x03;
//             pubKey = abi.encodePacked(startingByte, pubKeyX);
//         } else {
//             /* Uncompressed public key format */
//             require(!nested && !bech32, "HEX: claimFlags invalid");

//             startingByte = 0x04;
//             pubKey = abi.encodePacked(startingByte, pubKeyX, pubKeyY);
//         }

//         bytes20 pubKeyHash = _hash160(pubKey);
//         if (nested) {
//             return _hash160(abi.encodePacked(hex"0014", pubKeyHash));
//         }
//         return pubKeyHash;
//     }

//     function _merkleProofIsValid(bytes32 merkleLeaf, bytes32[] memory proof)
//         private
//         pure
//         returns (bool)
//     {
//         return MerkleProof.verify(proof, merkleTreeRoot, merkleLeaf);
//     }

//     function _btcAddressIsValid(bytes20 btcAddr, uint256 rawSatoshis, bytes32[] memory proof)
//         internal
//         pure
//         returns (bool)
//     {
//         /*
//             Ensure the proof does not attempt to treat a Merkle leaf as if it were an
//             internal Merkle tree node. A leaf will always have the zero-fill. An
//             internal node will never have the zero-fill, as guaranteed by HEX's Merkle
//             tree construction.

//             The first element, proof[0], will always be a leaf because it is the pair
//             of the leaf being validated. The rest of the elements, proof[1..length-1],
//             must be internal nodes.

//             The number of leaves (CLAIMABLE_BTC_ADDR_COUNT) is even, as guaranteed by
//             HEX's Merkle tree construction, which eliminates the only edge-case where
//             this validation would not apply.
//         */
//         require((uint256(proof[0]) & MERKLE_LEAF_FILL_MASK) == 0, "HEX: proof invalid");
//         for (uint256 i = 1; i < proof.length; i++) {
//             require((uint256(proof[i]) & MERKLE_LEAF_FILL_MASK) != 0, "HEX: proof invalid");
//         }

//         /*
//             Calculate the 32 byte Merkle leaf associated with this BTC address and balance
//                 160 bits: BTC address
//                  52 bits: Zero-fill
//                  45 bits: Satoshis (limited by MAX_BTC_ADDR_BALANCE_SATOSHIS)
//         */
//         bytes32 merkleLeaf = bytes32(btcAddr) | bytes32(rawSatoshis);

//         /* Verify the Merkle tree proof */
//         return _merkleProofIsValid(merkleLeaf, proof);
//     }

//     function btcAddressClaim(
//         uint256 rawSatoshis,
//         bytes32[] calldata proof,
//         address claimToAddr,
//         bytes32 pubKeyX,
//         bytes32 pubKeyY,
//         uint8 claimFlags,
//         uint8 v,
//         bytes32 r,
//         bytes32 s,
//         uint256 autoStakeDays,
//         address referrerAddr
//     )
//         internal
//         returns (uint256)
//     {
//         /* Sanity check */
//         require(rawSatoshis <= maxBTCAddressSatoshi, "HEX: CHK: rawSatoshis");

//         /* Enforce the minimum stake time for the auto-stake from this claim */
//         require(autoStakeDays >= 365, "HEX: autoStakeDays lower than minimum");

//         /* Ensure signature matches the claim message containing the Eth address and claimParamHash */
//         {
//             bytes32 claimParamHash = 0;

//             if (claimToAddr != msg.sender) {
//                 /* Claimer did not send this, so claim params must be signed */
//                 claimParamHash = keccak256(
//                     abi.encodePacked(merkleTreeRoot, autoStakeDays, referrerAddr)
//                 );
//             }

//             require(
//                 claimMessageMatchesSignature(
//                     claimToAddr,
//                     claimParamHash,
//                     pubKeyX,
//                     pubKeyY,
//                     claimFlags,
//                     v,
//                     r,
//                     s
//                 ),
//                 "HEX: Signature mismatch"
//             );
//         }

//         /* Derive BTC address from public key */
//         bytes20 btcAddr = pubKeyToBtcAddress(pubKeyX, pubKeyY, claimFlags);

//         /* Ensure BTC address has not yet been claimed */
//         require(!btcAddressClaimsValid[btcAddr], "HEX: BTC address balance already claimed");

//         /* Ensure BTC address is part of the Merkle tree */
//         require(
//             _btcAddressIsValid(btcAddr, rawSatoshis, proof),
//             "HEX: BTC address or balance unknown"
//         );

//         /* Mark BTC address as claimed */
//         btcAddressClaimsValid[btcAddr] = true;
//         return 0;
//         // return _satoshisClaimSync(
//         //     rawSatoshis,
//         //     claimToAddr,
//         //     btcAddr,
//         //     claimFlags,
//         //     autoStakeDays,
//         //     referrerAddr
//         // );
//     }
// }