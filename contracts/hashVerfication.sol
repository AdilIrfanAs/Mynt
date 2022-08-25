// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

contract SignatureVerification {

    /* Largest BTC address Satoshis balance in UTXO snapshot (sanity check) */
    uint256 internal constant MAX_BTC_ADDR_BALANCE_SATOSHIS = 25550214098481;
    /* Root hash of the UTXO Merkle tree */
    bytes32 internal constant MERKLE_TREE_ROOT = 0x7f595b64c3ad65759aaab71b3f4d0f8951ac89d869e170cd659926d9edc1cdbe;


        /* Claimed BTC addresses */
    mapping(bytes20 => bool) public btcAddressClaims;


    function btcAddressClaim(
        uint256 rawSatoshis,
        bytes32[] calldata proof,
        bytes32 messageHash,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (bool)
    {
        /* Sanity check */
        require(rawSatoshis <= MAX_BTC_ADDR_BALANCE_SATOSHIS, "Myntist: CHK: rawSatoshis");
         /* Enforce the minimum stake time for the auto-stake from this claim */
        // require(autoStakeDays >= MIN_AUTO_STAKE_DAYS, "Myntist: autoStakeDays lower than minimum");

        {
            require(
                claimMessageMatchesSignature(
                    pubKeyX,
                    pubKeyY,
                    messageHash,
                    v,
                    r,
                    s
                ),
                "Myntist: Signature mismatch"
            );
        }

         /* Derive BTC address from public key */
        bytes20 btcAddr = pubKeyToBtcAddress(pubKeyX, pubKeyY);

         /* Ensure BTC address has not yet been claimed */
        require(!btcAddressClaims[btcAddr], "Myntist: BTC address balance already claimed");

        /* Ensure BTC address is part of the Merkle tree */
        require(
            _btcAddressIsValid(btcAddr, rawSatoshis, proof),
            "Myntist: BTC address or balance unknown"
        );

        /* Mark BTC address as claimed */
        btcAddressClaims[btcAddr] = true;

        // Your airdrop logic and functions come here
        return true;
    }
    
    function claimMessageMatchesSignature(
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        pure
        returns (bool)
    {
        require(v >= 27 && v <= 30, "Myntist: v invalid");

        /*
            ecrecover() returns an Eth address rather than a public key, so
            we must do the same to compare.
        */
        address pubToEth = pubKeyToEthAddress(pubKeyX, pubKeyY);

        return  ecrecover(messageHash, v, r, s) == pubToEth;
    }

    function sigAddress(bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns(address){
        require(v >= 27 && v <= 30, "Myntist: v invalid");
        return ecrecover(messageHash, v, r, s);
    }


    function pubKeyToEthAddress(bytes32 pubKeyX, bytes32 pubKeyY)
        public
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(pubKeyX, pubKeyY)))));
    }

    function pubKeyToBtcAddress(bytes32 pubKeyX, bytes32 pubKeyY)
        public
        pure
        returns (bytes20)
    {
        /*
            Helpful references:
             - https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
             - https://github.com/cryptocoinjs/ecurve/blob/master/lib/point.js
        */
        uint8 startingByte;
        bytes memory pubKey;
        // bool compressed = (claimFlags & CLAIM_FLAG_BTC_ADDR_COMPRESSED) != 0;
        // bool nested = (claimFlags & CLAIM_FLAG_BTC_ADDR_P2WPKH_IN_P2SH) != 0;
        // bool bech32 = (claimFlags & CLAIM_FLAG_BTC_ADDR_BECH32) != 0;

        // if (compressed) {
        //     /* Compressed public key format */
        //     require(!(nested && bech32), "Myntist: claimFlags invalid");

        //     startingByte = (pubKeyY[31] & 0x01) == 0 ? 0x02 : 0x03;
        //     pubKey = abi.encodePacked(startingByte, pubKeyX);
        // } else {
            /* Uncompressed public key format */
            // require(!nested && !bech32, "Myntist: claimFlags invalid");

            startingByte = 0x04;
            pubKey = abi.encodePacked(startingByte, pubKeyX, pubKeyY);
        // }

        bytes20 pubKeyHash = _hash160(pubKey);
        // if (nested) {
        //     return _hash160(abi.encodePacked(hex"0014", pubKeyHash));
        // }
        return pubKeyHash;
    }

        /**
     * @dev ripemd160(sha256(data))
     * @param data Data to be hashed
     * @return 20-byte hash
     */
    function _hash160(bytes memory data)
        private
        pure
        returns (bytes20)
    {
        return ripemd160(abi.encodePacked(sha256(data)));
    }

    /**
     * @dev Verify a BTC address and balance are part of the Merkle tree
     * @param btcAddr Bitcoin address (binary; no base58-check encoding)
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @param proof Merkle tree proof
     * @return True if valid
     */
    function _btcAddressIsValid(bytes20 btcAddr, uint256 rawSatoshis, bytes32[] memory proof)
        internal
        pure
        returns (bool)
    {
        
        bytes32 merkleLeaf = keccak256(abi.encodePacked(btcAddr, rawSatoshis));

        return _merkleProofIsValid(merkleLeaf, proof);
    }

    /**
     * @dev Verify a Merkle proof using the UTXO Merkle tree
     * @param merkleLeaf Leaf asserted to be present in the Merkle tree
     * @param proof Generated Merkle tree proof
     * @return True if valid
     */
    function _merkleProofIsValid(bytes32 merkleLeaf, bytes32[] memory proof)
        private
        pure
        returns (bool)
    {
        return MerkleProof.verify(proof, MERKLE_TREE_ROOT, merkleLeaf);
    }
}

