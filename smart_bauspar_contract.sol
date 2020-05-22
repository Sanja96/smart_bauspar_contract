pragma solidity >0.6.0 <= 0.7.0;

//"SPDX-License-Identifier: UNLICENSED"

contract MetaKollektiv {
    /*
    In den Zeilen 11-14 werden mapping und arrays definiert, die die Vertreage
    aus dem Kollektiv beinhalten. Je nach Status des Vertrags kann dieser unterschiedlichen 
    Arrays zugeordnet werden. 
    */
    mapping(address => address payable) private BSVZuordnung;
    address[] Vertreage;
    address[] Sparphase;
    address[] Kreditphase;
    
    constructor() public payable {}
    
    function HinzfuegenAddresse(address payable BSVAdresse,address payable InhaberAdresse) public returns(string memory) {
        /* 
        MetaStorage: Sobald ein neuer Bausparvertrag angelegt wird,
        werden die Addressend des BSV und die Addresse des Eigentuemers festgehalten.
        Neuer Bausparvertrag  wird außerdem im Array für Sparvertraege eingetragen.
        */
        BSVZuordnung[BSVAdresse] = InhaberAdresse;
        Vertreage.push(BSVAdresse);
        Sparphase.push(BSVAdresse);
        return "Neuer Bausparvertrag wurde erfolgreich im Kollektiv erfasst!";
    }
    
    function Zugriffsberechtigung(address BSVAdresse) private view returns(bool) {
        bool gueltig = false;
        for (uint i=0; i<Vertreage.length; i++) {
            if (Vertreage[i] == BSVAdresse) {
                gueltig = true;
            }
        }
        return gueltig;
    }

    function GuthabenAuszahlen(address payable BSVAdresse,uint Auszahlung) external payable {
        require(Zugriffsberechtigung(BSVAdresse) == true,"Keine Berechtigung zum Zugriff");
        Bausparvertrag bsv = Bausparvertrag(BSVAdresse);
        require(address(this).balance > 0,"Nicht ausreichend Liquiditaet im kollektiv");
        BSVZuordnung[address(bsv)].transfer(Auszahlung);
        /* 
        Informationen zum Vertrag löschen nach 
        Ausbezahlen vom Guthaben.
        */
        delete BSVZuordnung[BSVAdresse];
        bool loop = false;
        uint i = 0;
        while(!loop) {
            if (Sparphase[i] == BSVAdresse) {
                delete Sparphase[i];
                loop = true;
            } else i++;
        }
    }
    
    function KreditAuszahlen(address payable BSVAdresse,uint Auszahlung) external payable returns(string memory) {
        require(Zugriffsberechtigung(BSVAdresse) == true,"Keine Berechtigung zum Zugriff");
        Bausparvertrag bsv = Bausparvertrag(BSVAdresse);
        require(address(this).balance > 0,"Nicht ausreichend Liquiditaet im kollektiv");
        BSVZuordnung[address(bsv)].transfer(Auszahlung);
    }
    
    function getMetadata() public view returns(uint,uint,uint,uint,uint) {
        //ToDo: Anzahl an Krediten im Kollektiv und ausgezahltes Volumen
        return (Vertreage.length,Sparphase.length,Kreditphase.length,address(this).balance,0);
    }
    
    function getVertrag(address BSVAdresse) public view returns(address) {
        return BSVZuordnung[BSVAdresse];
    }
    
    receive() external payable { }
    
    fallback() external payable { }
    
}

contract Bausparvertrag {
    //Alle wichtigen e Adressen
    address payable owner;
    //address payable _kollektiv = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    address payable _metakollektiv = 0x3643b7a9F6338115159a4D3a2cc678C99aD657aa;

    //Informationen über Vertrags-InhaberIn
    address payable bsv_address = address(this);
    uint256 private BausparSumme;
    int256 private Kreditsumme;
    uint256 public AnzahlInhaber = 0;
    mapping(uint => Person) public Inhaber;
    
    MetaKollektiv k;
    
    struct Person {
        uint _id;
        string _Vorname;
        string _Nachname;
        address _ZahlungsAdresse;
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
        require(msg.sender == owner || msg.sender == _metakollektiv);
        _;
    }
    
    //Initialisiere Vertag inkl. Abschlussgebuehr
    constructor(uint256 _summe,string memory _firstname, string memory _lastname) public payable{
        //Speichere Inhaber Informationen
        require(_summe >= 1,"Zu kleine Bausparsumme");
        owner = msg.sender;
        AnzahlInhaber += 1;
        Inhaber[AnzahlInhaber] = Person(AnzahlInhaber,_firstname,_lastname,owner,bsv_address);
        BausparSumme = _summe * 10^18;
        Guthaben = 0 - (int(BausparSumme) / 100); //Abschlussgebuehr zahlen 1.0%
        ZahlungsHistorie[NumZahlung] = Details(0,VertragsAbschluss,'Vertragsabschluss');
        /*Meta Kollektiv Reporting*/
        k = MetaKollektiv(_metakollektiv);
        k.HinzfuegenAddresse(bsv_address,owner);
    }

    function HinzufuegenInhaber(string memory _firstname,string memory _lastname) public returns(string memory) {
        /* 
        Hinzufügen eines neuen Inhabers zum Vertrag.
        */
        AnzahlInhaber += 1;
        Inhaber[AnzahlInhaber] = Person(AnzahlInhaber,_firstname,_lastname,owner,bsv_address);
        return "Neuer Inhaber hinzugefuegt.";
    }

    function Sparen() public payable nurInhaber returns(string memory) {
        /*
        Sparvorgang: Zahlung von Sparraten an das Kollektiv.
        Sparen ist grundsätzlich nur in der Phase 'Sparphase' möglich.
        Zahlungen und Details zur Zahlung werden protokolliert
        */
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase'))) {
            address(k).transfer(msg.value);
            Guthaben += (int256) (msg.value);
            SparEingang = block.timestamp;
            NumZahlung += 1;
            
            ZahlungsHistorie[NumZahlung] = Details(msg.value,SparEingang,Phase); 
            return "Sparvorgang wurde erfolgreich abgeschlossen";
        } else {
            return "Sparen nur in Sparphase möglich";
        }
    }
    
    function Auszahlen() public payable nurInhaber returns(string memory){
        /* 
        Vertragsguthaben vorzeitig ausszahlen lassen (ohne Anspruch auf Darlehen)
        Dabei wird das Guthaben des Vertrages an die Besitzer Adresse erstattet. 
        Vertrag wird bereinigt und auf 'null' gesetzt.
        */
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase')) && Guthaben > 0) {
            k.GuthabenAuszahlen(bsv_address,uint(Guthaben));
            Phase = 'Ausbezahlt';
            NumZahlung += 1;
            ZahlungsHistorie[NumZahlung] = Details(uint(Guthaben),block.timestamp,Phase);
            Guthaben = 0;
            return "Rückzahlung von Kollektiv erfolgreich";
        } else {
            return "Auszahlung nicht möglich";
        }
    }
    
    function ZuteilungsReife() public view returns(bool) { 
        /*
        Berechnung der Kennzahlen zur Ermittlung der ZuteilungsReife
        des Vertrags. Hierzu wird ermittelt, wie viel Prozent von der BausparSumme
        bei der Initialisierung des Vertrags bereits durch Guthaben eingezahlt wurde.
        Außerdem muss der Vertrag eine gewisse Mindestsparzeit aufweisen um Zuteilungsreif zu sein.
        Leifert ZuteilungsReife ein true, so ist der Vertrag für eine Auszahlung eines Kreditphase
        aus dem Kollektiv berechtigt.
        */
        int Eingezahlt;
        uint DauerSparphase = ZahlungsHistorie[NumZahlung]._Zeitpunkt - ZahlungsHistorie[0]._Zeitpunkt;
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase')) && Guthaben > 0) {
            Eingezahlt = (Guthaben / int(BausparSumme)) * 100;
            if (Eingezahlt >= 45 && DauerSparphase >= 100) {
                return true;
            } else return false;
        } else return false;
    }
    
    function KreditAntrag() public nurInhaber returns(string memory) {
        if (ZuteilungsReife() == true) {
            Phase = 'Kreditphase';
            Kreditsumme = int(BausparSumme) - Guthaben;
        }
    }
    
    /*Getter Funktionen vom Vertrag definiert*/
    
    function KontoSaldo() public view nurInhaber returns(int){
        return Guthaben;
    }
    
    function getKollektiv() public view nurInhaber returns(uint256){
        return address(k).balance;
    }
    
    /*Fallback und Receiver Funktionen*/
    
    receive() external payable { x = 2; y = msg.value; }
    uint x;
    uint y;
    
    fallback() external payable {}
}
