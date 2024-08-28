// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IMerkleTreeOperator {
    function appendMerkleLeaf(bytes32 leaf) external;
    function setNoteCommitmentCreated(bytes32 commitment) external;
    function setNullifierUsed(bytes32 nullifier) external;
    function setNullifierLocked(bytes32 nullifier, bool locked) external;
    function setNoteFooterUsed(bytes32 noteFooter) external;

    function isRelayerRegistered(address _relayer) external view returns (bool);

    function merkleRootIsAllowed(
        bytes32 _merkleRoot
    ) external view returns (bool);

    function nullifierIsNotUsed(
        bytes32 _nullifier
    ) external view returns (bool);
   
    function nullifierIsNotLocked(
        bytes32 _nullifier
    ) external view returns (bool);

    function noteIsNotCreated(
        bytes32 _noteCommitment
    ) external view returns (bool);

    function noteFooterIsNotUsed(
        bytes32 _noteFooter
    ) external view returns (bool);

    function getMerkleRoot() external view returns (bytes32);

    function getMerklePath(
        bytes32 _noteCommitment
    ) external view returns (bytes32[] memory, bool[] memory, bytes32);
}
