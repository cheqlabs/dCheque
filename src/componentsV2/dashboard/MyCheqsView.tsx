import { Box, Center, Grid, Select, Text } from "@chakra-ui/react";
import { useState } from "react";
// import { useTokens } from "../../hooks/useTokens";
import CheqCardV2 from "./CheqCardV2";
import SkeletonGrid from "./SkeletonGrid";

function MyCheqsView() {
  const [tokenField, setTokenField] = useState("tokensReceived");
  const tokens: any[] | undefined = undefined;
  // TODO (Integrate v2 UI with v2 smart contract): Load cheqs from graph:
  // const tokens = useTokens(tokenField, true);

  return (
    <Box boxShadow="outline" width="100%" p={6} borderRadius={"10px"}>
      <Select
        defaultValue={"tokensReceived"}
        minW={0}
        mb={6}
        w="120px"
        onChange={(event) => {
          setTokenField(event.target.value);
        }}
      >
        <option value="">All</option>
        <option value="tokensReceived">Received</option>
        <option value="tokensSent">Sent</option>
        <option value="tokensCashed">Cashed</option>
        <option value="tokensVoided">Voided</option>
      </Select>
      <CheqGrid tokens={tokens} />
    </Box>
  );
}

interface CheqGridProps {
  tokens: any[] | undefined;
}

function CheqGrid({ tokens }: CheqGridProps) {
  if (tokens === undefined) {
    return <SkeletonGrid />;
  }

  if (tokens.length === 0) {
    return (
      <Center>
        <Text fontWeight={600} fontSize={"xl"} textAlign="center">
          {"No cheqs found"}
        </Text>
      </Center>
    );
  }

  return (
    <Grid templateColumns="repeat(auto-fit, minmax(240px, 1fr))" gap={6}>
      <CheqCardV2
        sender="Cheq 1"
        status="Cashable"
        token="USDC"
        amount="1000"
      />
      <CheqCardV2 sender="Cheq 2" status="Cashable" token="USDC" amount="500" />
      <CheqCardV2 sender="Cheq 3" status="Cashable" token="USDC" amount="900" />
      <CheqCardV2 sender="Cheq 4" status="Cashable" token="USDC" amount="250" />
    </Grid>
  );
}

export default MyCheqsView;
