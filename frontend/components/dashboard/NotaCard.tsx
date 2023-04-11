import { ArrowForwardIcon } from "@chakra-ui/icons";
import {
  Button,
  ButtonGroup,
  Center,
  Flex,
  GridItem,
  HStack,
  Menu,
  MenuButton,
  MenuItem,
  MenuList,
  Spinner,
  Text,
  Tooltip,
  useDisclosure,
  VStack,
} from "@chakra-ui/react";
import { useCallback, useMemo, useState } from "react";
import {
  MdOutlineAttachMoney,
  MdOutlineClose,
  MdOutlineDoneAll,
  MdOutlineHourglassEmpty,
  MdOutlineLock,
} from "react-icons/md";
import { useCashNota } from "../../hooks/useCashNota";
import { useCurrencyDisplayName } from "../../hooks/useCurrencyDisplayName";
import { useFormatAddress } from "../../hooks/useFormatAddress";
import { Nota } from "../../hooks/useNotas";
import CurrencyIcon from "../designSystem/CurrencyIcon";
import DetailsModal from "./details/DetailsModal";
import ApproveAndPayModal from "./pay/ApproveAndPayModal";

interface Props {
  nota: Nota;
}

const TOOLTIP_MESSAGE_MAP = {
  payable: "payment requested",
  paid: "paid",
  awaiting_payment: "awaiting payment",
  voided: "voided by inspector",
  released: "released by inspector",
  awaiting_release: "waiting for payer to release funds",
  releasable: "payment can be released or voided",
  awaiting_escrow: "waiting for payer to escrow funds",
};

function NotaCard({ nota }: Props) {
  const hashCode = (s: string) =>
    s.split("").reduce((a, b) => {
      a = (a << 5) - a + b.charCodeAt(0);
      return a & a;
    }, 0);
  const GRADIENT_COLORS = [
    ["#6E7C9A", "#202C4F"],
    ["#8691A4", "#3F444D"],
    ["#9099A2", "#283455"],
    ["#343C9B", "#292D5D"],
    ["#A59EA9", "#3B475A"],
    ["#B4A4D480", "#4E4D5C48"],
    ["#C1C1C151", "#1C1C1C53"],
    ["#6D4C41", "#E6B8B89F"],
  ];

  const generateNotaGradient = (nota: Nota): string => {
    const { id, amount, sender, receiver } = nota;
    const hash = hashCode(`${id}${amount}${sender}${receiver}`);
    const colorIndex = Math.abs(hash) % GRADIENT_COLORS.length;
    const [startColor, endColor] = GRADIENT_COLORS[colorIndex];
    return `linear-gradient(180deg, ${startColor}, ${endColor})`;
  };

  const { createdTransaction } = nota;

  const createdLocaleDate = useMemo(() => {
    return createdTransaction.date.toLocaleDateString();
  }, [createdTransaction.date]);
  const {
    isOpen: isDetailsOpen,
    onOpen: onOpenDetails,
    onClose: onCloseDetails,
  } = useDisclosure();

  const {
    isOpen: isPayOpen,
    onOpen: onOpenPay,
    onClose: onClosePay,
  } = useDisclosure();

  const { formatAddress } = useFormatAddress();

  const icon = useMemo(() => {
    switch (nota.moduleData.status) {
      case "paid":
        return <MdOutlineDoneAll color="white" size={20} />;
      case "payable":
        return <MdOutlineAttachMoney color="white" size={20} />;
      case "awaiting_payment":
        return <MdOutlineHourglassEmpty color="white" size={20} />;
      case "releasable":
        return <MdOutlineLock color="white" size={20} />;
      case "awaiting_release":
        return <MdOutlineLock color="white" size={20} />;
      case "released":
        return <MdOutlineDoneAll color="white" size={20} />;
      case "voided":
        return <MdOutlineClose color="white" size={20} />;
      default:
        return <MdOutlineHourglassEmpty color="white" size={20} />;
    }
  }, [nota.moduleData.status]);

  const iconColor = useMemo(() => {
    switch (nota.moduleData.status) {
      case "paid":
        return "#00C28E";
      case "released":
        return "#00C28E";
      case "payable":
        return "#4A67ED";
      case "releasable":
        return "#4A67ED";
      case "awaiting_payment":
        return "#C5CCD8";
      case "awaiting_escrow":
        return "#C5CCD8";
      case "voided":
        return "#E53E3E";
      default:
        return "#4A67ED";
    }
  }, [nota.moduleData.status]);
  const gradient = generateNotaGradient(nota);

  const { displayNameForCurrency } = useCurrencyDisplayName();

  const [cashingInProgress, setCashingInProgress] = useState(false);

  const { release, reverse } = useCashNota();

  const handleRelease = useCallback(async () => {
    setCashingInProgress(true);
    await release({
      cheqId: nota.id,
    });
    setCashingInProgress(false);
  }, [nota.id, release]);

  const handleVoid = useCallback(async () => {
    setCashingInProgress(true);
    await reverse({
      cheqId: nota.id,
    });
    setCashingInProgress(false);
  }, [nota.id, reverse]);

  return (
    <GridItem bg={gradient} px={6} pt={4} pb={3} borderRadius={20}>
      <VStack
        alignItems="flex-start"
        justifyContent="space-between"
        h="100%"
        gap={2.5}
      >
        <Flex
          alignItems="flex-start"
          flexDirection="column"
          maxW="100%"
          w="100%"
          gap={2.5}
        >
          <HStack justifyContent={"space-between"} w="100%">
            <Text textOverflow="clip" noOfLines={1} fontSize="lg">
              {createdLocaleDate}
            </Text>
            <Tooltip
              label={TOOLTIP_MESSAGE_MAP[nota.moduleData.status]}
              aria-label="status tooltip"
              placement="bottom"
              bg="brand.100"
              textColor="white"
            >
              <Center
                bgColor={iconColor}
                aria-label="status"
                borderRadius={"full"}
                w={"30px"}
                h={"30px"}
              >
                {icon}
              </Center>
            </Tooltip>
          </HStack>
          <HStack maxW="100%">
            <Text
              fontWeight={600}
              fontSize={"xl"}
              textOverflow="clip"
              noOfLines={1}
            >
              {formatAddress(nota.payer)}
            </Text>
            <ArrowForwardIcon mx={2} />
            <Text
              fontWeight={600}
              fontSize={"xl"}
              textOverflow="clip"
              noOfLines={1}
            >
              {formatAddress(nota.payee)}
            </Text>
          </HStack>

          <HStack>
            <Text fontWeight={400} fontSize={"xl"} my={0}>
              {nota.amount}{" "}
              {displayNameForCurrency(nota.token, nota.sourceChainHex)}
            </Text>

            <CurrencyIcon
              currency={nota.token}
              sourceChainHex={nota.sourceChainHex}
            />
          </HStack>
        </Flex>

        <VStack alignItems="flex-start" w="100%">
          <Center w="100%">
            <ButtonGroup>
              {nota.moduleData.status === "payable" ? (
                <Button
                  variant="outline"
                  w="min(40vw, 100px)"
                  borderRadius={5}
                  colorScheme="teal"
                  onClick={onOpenPay}
                >
                  Pay
                </Button>
              ) : null}
              {nota.moduleData.status === "releasable" ? (
                <Menu>
                  <MenuButton disabled={cashingInProgress} as={Button} minW={0}>
                    Options {cashingInProgress ? <Spinner size="xs" /> : null}
                  </MenuButton>
                  <MenuList alignItems={"center"}>
                    <MenuItem onClick={handleRelease}>Release</MenuItem>
                    <MenuItem onClick={handleVoid}>Void</MenuItem>
                  </MenuList>
                </Menu>
              ) : null}
              <Button
                variant="outline"
                w="min(40vw, 100px)"
                borderRadius={5}
                onClick={onOpenDetails}
              >
                Details
              </Button>
            </ButtonGroup>
          </Center>
        </VStack>
      </VStack>
      <DetailsModal
        isOpen={isDetailsOpen}
        onClose={onCloseDetails}
        nota={nota}
      />
      <ApproveAndPayModal isOpen={isPayOpen} onClose={onClosePay} nota={nota} />
    </GridItem>
  );
}

export default NotaCard;