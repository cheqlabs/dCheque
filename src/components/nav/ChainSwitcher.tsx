import { useState } from "react";

import { ChevronDownIcon, ChevronUpIcon } from "@chakra-ui/icons";
import {
  Button,
  Flex,
  Menu,
  MenuButton,
  MenuItem,
  MenuList,
  Spacer,
  Text,
} from "@chakra-ui/react";
import Image from "next/image";

import { deployedChains } from "../../context/chainInfo";
import { switchNetwork } from "../../context/SwitchNetwork";

interface ChainSwitcherProps {
  chainId: string;
}

export default function ChainSwitcher({ chainId }: ChainSwitcherProps) {
  const filteredChains = Object.values(deployedChains).map((chain) => {
    const { displayName, chainId, logoSrc, isDisabled } = chain;
    return { displayName, chainId, logoSrc, isDisabled };
  });

  const [selectedChain, setSelectedChain] = useState(
    filteredChains.find((chain) => chain.chainId === chainId) ??
      filteredChains[0]
  );
  const [isOpen, setIsOpen] = useState(false);

  const handleSelectChain = async (chain: {
    displayName: string;
    chainId: string;
    logoSrc: string;
    isDisabled?: boolean;
  }) => {
    const { displayName, chainId, logoSrc, isDisabled } = chain;
    setSelectedChain({ displayName, chainId, logoSrc, isDisabled });
    setIsOpen(false);
    await switchNetwork(chain.chainId);
  };

  return (
    <Menu isOpen={isOpen} onClose={() => setIsOpen(false)}>
      <MenuButton
        as={Button}
        variant="ghost"
        rightIcon={isOpen ? <ChevronUpIcon /> : <ChevronDownIcon />}
        size="sm"
        mr={2}
        aria-label="Select chain"
        onClick={() => setIsOpen(!isOpen)}
      >
        <Flex alignItems="center">
          <Image
            src={selectedChain.logoSrc}
            alt={selectedChain.displayName}
            width={20}
            height={20}
            unoptimized={true}
          />
          <Spacer mx="1" />
          <Text fontSize="lg">{selectedChain.displayName}</Text>
        </Flex>
      </MenuButton>
      <MenuList bg="brand.100">
        {filteredChains.map((chain) => (
          <MenuItem
            key={chain.chainId}
            onClick={() => handleSelectChain(chain)}
            isDisabled={chain.isDisabled}
            bg="brand.100"
            _hover={{ bg: "brand.400" }}
            fontSize="lg"
          >
            <Flex alignItems="center">
              <Image
                src={chain.logoSrc}
                alt={chain.displayName}
                width={20}
                height={20}
                unoptimized={true}
              />
              <Spacer mx="1" />
              {chain.displayName}
            </Flex>
          </MenuItem>
        ))}
      </MenuList>
    </Menu>
  );
}