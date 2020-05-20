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
    
    bool Zugriffsberechtigung;
    
    constructor() public payable {}
    
    function addAdress(address payable BSVAdresse,address payable InhaberAdresse) public returns(string memory) {
        BSVZuordnung[BSVAdresse] = InhaberAdresse;
        Vertreage.push(BSVAdresse);
        Sparphase.push(BSVAdresse);
        return "Neuer Bausparvertrag wurde erfolgreich im Kollektiv erfasst!";
    }

    function GuthabenAuszahlen(address payable BSVAdresse,uint Auszahlung) external payable {
        Zugriffsberechtigung = false;
        for (uint i=0; i<Vertreage.length; i++) {
            if (Vertreage[i] == BSVAdresse) {
                Zugriffsberechtigung = true;
            }
        }
        require(Zugriffsberechtigung == true,"Keine Berechtigung zum Zugriff");
        
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
    int256 private BausparSumme;
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
        int256 _ProzEingezahlt;
    }
    mapping(uint => Details) public ZahlungsHistorie;

    //Inhaber des Vertrags darf Funktionen ausführen
    modifier nurInhaber() {
        require(msg.sender == owner || msg.sender == _metakollektiv);
        _;
    }
    
    //Initialisiere Vertag inkl. Abschlussgebuehr
    constructor(int256 _summe,string memory _firstname, string memory _lastname) public payable{
        //Speichere Inhaber Informationen
        require(_summe >= 1,"Zu kleine Bausparsumme");
        owner = msg.sender;
        AnzahlInhaber += 1;
        Inhaber[AnzahlInhaber] = Person(AnzahlInhaber,_firstname,_lastname,owner,bsv_address);
        BausparSumme = _summe * 10^18;
        Guthaben = 0 - (BausparSumme / 100); //Abschlussgebuehr zahlen 1.0%
        ZahlungsHistorie[NumZahlung] = Details(0,VertragsAbschluss,'Vertragsabschluss',0);
        /*Meta Kollektiv Reporting*/
        k = MetaKollektiv(_metakollektiv);
        k.addAdress(bsv_address,owner);
    }

    function addInhaber(string memory _firstname,string memory _lastname) public returns(string memory) {
        AnzahlInhaber += 1;
        Inhaber[AnzahlInhaber] = Person(AnzahlInhaber,_firstname,_lastname,owner,bsv_address);
        return "Neuer Inhaber hinzugefuegt.";
    }

    function sparen() public payable nurInhaber returns(string memory) {
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase'))) {
            address(k).transfer(msg.value);
            Guthaben += (int256) (msg.value);
            SparEingang = block.timestamp;
            NumZahlung += 1;
            ZahlungsHistorie[NumZahlung] = Details(msg.value,SparEingang,Phase,(Guthaben / BausparSumme)*100); 
            return "Sparvorgang wurde erfolgreich abgeschlossen";
        } else {
            return "Sparen nur in Sparphase möglich";
        }
    }
    
    function auszahlen() public payable nurInhaber returns(string memory){
        if (keccak256(bytes(Phase)) == keccak256(bytes('Sparphase')) && Guthaben > 0) {
            k.GuthabenAuszahlen(bsv_address,uint(Guthaben));
            Phase = 'Ausbezahlt';
            NumZahlung += 1;
            ZahlungsHistorie[NumZahlung] = Details(uint(Guthaben),block.timestamp,Phase,0);
            Guthaben = 0;
            return "Rückzahlung von Kollektiv erfolgreich";
        } else {
            return "Auszahlung nicht möglich";
        }
    }
    
    function KontoSaldo() public view nurInhaber returns(int){
        return Guthaben;
    }
    
    function getKollektiv() public view nurInhaber returns(uint256){
        return address(k).balance;
    }
    
    function posGuthaben() public view nurInhaber returns(bool){
        return Guthaben > 0;
    }
    
    receive() external payable { x = 2; y = msg.value; }
    uint x;
    uint y;
    
    fallback() external payable {}
}
