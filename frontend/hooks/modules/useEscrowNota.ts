import { write } from "@denota-labs/denota-sdk";
import { useCallback } from "react";
import { useBlockchainData } from "../../context/BlockchainDataProvider";

interface Props {
  token: string;
  amount: string;
  address: string;
  ipfsHash: string;
  imageUrl: string;
  isInvoice: boolean;
  inspector?: string;
}

export const useEscrowNota = () => {
  const { blockchainState } = useBlockchainData();

  const writeNota = useCallback(
    async ({
      token,
      amount,
      address,
      ipfsHash,
      inspector,
      imageUrl,
    }: Props) => {
      const receipt = await write({
        amount: Number(amount),
        currency: token,
        metadata: { type: "uploaded", ipfsHash, imageUrl },
        module: {
          moduleName: "reversibleRelease",
          payee: address,
          payer: blockchainState.account,
          inspector,
        },
      });
      return receipt;
    },
    [blockchainState.account]
  );

  return { writeNota };
};