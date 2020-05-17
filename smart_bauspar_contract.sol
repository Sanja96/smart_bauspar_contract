pragma solidity >= 0.4.0 < 0.7.0;

contract Kollektiv {
    address payable private constant kollektiv  = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    mapping(address => address payable) BSVZuordnung;
    
    function addAdress(address BSVAdresse,address payable InhaberAdresse) public returns(string memory) {
        BSVZuordnung[BSVAdresse] = InhaberAdresse;
        return "Neue Zuordnung erfolgt!";
    }
    
    function GuthabenAuszahlen(address payable InhaberAdresse,uint Guthaben) public payable returns(string memory) {
        InhaberAdresse.transfer(Guthaben);
        return "Guthaben wurde ausgezahlt";
    } 
}

contract Bausparvertrag {
    //Alle wichtigen e Adressen
    address payable owner;
    address payable public constant kollektiv = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    
    Kollektiv k = Kollektiv(kollektiv);

    //Informationen über Vertrags-InhaberIn
    address bsv_address = address(this);
    uint256 public AnzahlInhaber = 0;
    mapping(uint => person) public Inhaber;

    struct person {
        uint _id;
        string _Vorname;
        string _Nachname;
        address _BsvAdresse;
    }

    //Bausparvertrag relevante Werte
    int private Guthaben;
    string public Phase = "Sparphase";
    uint private Bewertungszahl = 0;

    //Zeitrechnung
    uint256 public NumZahlung = 0;
    uint256 public VertragsAbschluss = block.timestamp; //Vertrags-Abschluss
    uint256 private SparEingang = 0;
    struct Details {
        uint256 _Zahlung;
        uint256 _Zeitpunkt;
        string _ZustandVertrag;
    }
    mapping(uint => Details) public ZahlungsHistorie;

    //Inhaber des Vertrags darf Funktionen ausführen
    modifier nurInhaber() {
        require(msg.sender == owner);
        _;
    }

    //Initialisiere Vertag inkl. Abschlussgebuehr
    constructor(int _summe,string memory _firstname, string memory _lastname) public {
        //Speichere Inhaber Informationen
        owner = msg.sender;
        AnzahlInhaber += 1;
        Inhaber[AnzahlInhaber] = person(AnzahlInhaber,_firstname,_lastname,bsv_address);

        Guthaben = 0 - (_summe / 1000); //Abschlussgebuehr zahlen 0.1%
        
        ZahlungsHistorie[NumZahlung] = Details(0,VertragsAbschluss,'Vertragsabschluss');
        
        //k.addAdress(bsv_address,owner);
    }

    function addInhaber(string memory _firstname,string memory _lastname) public returns(string memory) {
        AnzahlInhaber += 1;
        Inhaber[AnzahlInhaber] = person(AnzahlInhaber,_firstname,_lastname,bsv_address);
        return "Neuer Inhaber hinzugefuegt.";
    }

    function sparen() public payable nurInhaber returns(string memory) {
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase'))) {
            kollektiv.transfer(msg.value);
            Guthaben += (int256) (msg.value);
            SparEingang = block.timestamp;
            NumZahlung += 1;
            ZahlungsHistorie[NumZahlung] = Details(msg.value,SparEingang,Phase); 
            return "Sparvorgang wurde erfolgreich abgeschlossen";
        } else {
            return "Sparen nur in Sparphase möglich";
        }
    }
    
    function auszahlen() public /*payable*/ returns(string memory){
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase')) && Guthaben > 0) {
            k.GuthabenAuszahlen(owner,uint256(Guthaben));
            return "Rückzahlung von Kollektiv erfolgreich";
        } else {
            return "Auszahlung nicht möglich";
            
        }
    }
    
    function KontoSaldo() public view nurInhaber returns(int){
        return Guthaben;
    }
    
    function getKollektiv() public view nurInhaber returns(uint256){
        return address(kollektiv).balance;
    }

    function posGuthaben() public view nurInhaber returns(bool){
        return Guthaben > 0;
    }
}
