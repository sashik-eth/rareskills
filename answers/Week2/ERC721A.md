## How does ERC721A save gas?
By saving owner address once per batch of minted NFTs instead of standard "1 id - 1 owner address" approach.
## Where does it add cost?
It add cost later when minted NFTs would be transferred, since it would require more storage updates.
## Why shouldn’t ERC721A enumerable’s implementation be used on-chain?
Since it's use a lot more storage variables and provides additional functionality that could be realized by off-chain indexers.