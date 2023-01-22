CREATE TABLE Company (
CName VARCHAR(255) PRIMARY KEY NOT NULL,
Address VARCHAR(255),
Website VARCHAR(255),
);

CREATE TABLE Employee (
EmployeeID INT PRIMARY KEY IDENTITY(1,1),
CName VARCHAR(255) NOT NULL,
FirstName VARCHAR(40) NOT NULL,
LastName VARCHAR(40),
emailAddress VARCHAR(255) NOT NULL UNIQUE,
phoneNumber VARCHAR(255) NOT NULL UNIQUE,
salary int,
gender CHAR(1) NOT NULL CHECK (gender IN ('M', 'F')),
dateOfBirth DATE NOT NULL,
FOREIGN KEY (CName) REFERENCES Company (CName)
);

CREATE TABLE Team (
TeamID INT PRIMARY KEY IDENTITY(1,1),
TName VARCHAR(40) NOT NULL
);

Create Table Manager (
 ManagerID int REFERENCES Employee(EmployeeID),
 TeamID int REFERENCES Team(TeamID)
 );

  Create Table Stuff (
 StuffID int REFERENCES Employee(EmployeeID),
 TeamID int REFERENCES Team(TeamID)
 );


CREATE TABLE CustomerCompany (
CompanyID INT IDENTITY(1,1),
CName VARCHAR(40) NOT NULL,
contactmail VARCHAR(40) NOT NULL,
phoneNumber VARCHAR(40) NOT NULL,
totalPurchase int,
INDEX CustomerCompany_index(CName, contactmail),
CONSTRAINT CustomerCompanyPK PRIMARY KEY (CompanyID)
);

CREATE TABLE Product (
ProductID INT IDENTITY(1,1),
ProductName VARCHAR(40) NOT NULL,
Description VARCHAR(255) NOT NULL,
CONSTRAINT ProductPK PRIMARY KEY (ProductID)
);
ALTER TABLE Product
ADD ProductPrice int;


CREATE TABLE Ordering (
OrderID INT PRIMARY KEY IDENTITY(1,1),
CompanyID INT NOT NULL,
ProductID INT NOT NULL,
orderDate DATE NOT NULL DEFAULT GETDATE(),
FOREIGN KEY (CompanyID) REFERENCES CustomerCompany (CompanyID),
FOREIGN KEY (ProductID) REFERENCES Product (ProductID),
EmployeeID int REFERENCES Employee(EmployeeID) 
);

CREATE TABLE Delivery (
DeliveryID INT PRIMARY KEY IDENTITY(1,1),
OrderID INT NOT NULL,
ShipToCountry VARCHAR(40) NOT NULL,
ShipToRegion VARCHAR(40) NOT NULL,
ETD DATE,
ETA DATE,
LogisticType VARCHAR(40) NOT NULL,
ProductTravelTime AS DATEDIFF(day,ETD,ETA),
INDEX Delivery_index(OrderID, ShipToCountry),
FOREIGN KEY (OrderID) REFERENCES Ordering (OrderID)
);

CREATE TABLE Bill (
Bill_ID INT PRIMARY KEY IDENTITY(1,1),
ProductID int REFERENCES Product(ProductID),
OrderID INT NOT NULL,
Volume INT NOT NULL,
PaymentTerms VARCHAR(255),
CHECK (volume>0),
FOREIGN KEY (OrderID) REFERENCES Ordering (OrderID)
);

Create Index PriceElements  --An index to get the price information.
  ON Bill (volume,ProductID);
  go
 --This Trigger when we add a bill of an order it helps us keep track of companies total purshcase or if we cancel a bill.
 CREATE TRIGGER update_CompanyPrice
ON Bill
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @Bill_ID INT, @OrderID INT, @CompanyID INT, @TotalPrice INT;

    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        
        SELECT @Bill_ID = Bill_ID, @OrderID = OrderID
        FROM inserted;

        SELECT @CompanyID = CompanyID, @TotalPrice = SUM(Volume * ProductPrice)
        FROM Ordering o, Product p, Bill b
        where o.ProductID = p.ProductID
        and  o.OrderID = b.OrderID
        and b.Bill_ID = @Bill_ID
        GROUP BY CompanyID;

       
        UPDATE CustomerCompany
        SET totalPurchase = totalPurchase + @TotalPrice
        WHERE CompanyID = @CompanyID;
    END
    ELSE
    BEGIN
        -- retrieve values from deleted row
        SELECT @Bill_ID = Bill_ID, @OrderID = OrderID
        FROM deleted;

        SELECT @CompanyID = CompanyID, @TotalPrice = SUM(Volume * ProductPrice)
        FROM Ordering o, Product p, Bill b
        WHERE o.ProductID = p.ProductID
        and o.OrderID = b.OrderID
        and b.Bill_ID = @Bill_ID
        GROUP BY CompanyID;

        -- update totalPurchase for company
        UPDATE CustomerCompany
        SET totalPurchase = totalPurchase - @TotalPrice
        WHERE CompanyID = @CompanyID;
    END
END
go

CREATE PROCEDURE AddEmployee
(
    @CName VARCHAR(255),
    @FirstName VARCHAR(40),
    @LastName VARCHAR(40),
    @emailAddress VARCHAR(255),
    @phoneNumber VARCHAR(255),
    @salary INT,
    @gender CHAR(1),
    @dateOfBirth DATE
)
AS
BEGIN
    INSERT INTO Employee (CName, FirstName, LastName, emailAddress, phoneNumber, salary, gender, dateOfBirth)
    VALUES (@CName, @FirstName, @LastName, @emailAddress, @phoneNumber, @salary, @gender, @dateOfBirth);
    SELECT * From Employee e where e.emailAddress=@emailAddress
END;
go


CREATE PROCEDURE UpdateSalary
(
    @EmployeeID INT,
    @newSalary INT
)
AS
BEGIN
    Select e.salary AS 'OLD Salary' From Employee e where e.EmployeeID=@EmployeeID
    UPDATE Employee
    SET salary = @newSalary
    WHERE EmployeeID = @EmployeeID;
	Select e.salary AS 'NEW Salary' From Employee e where e.EmployeeID=@EmployeeID
END;
go


CREATE PROCEDURE GetOrderedProducts -- This Procedure gets the Product that spesific company Ordered.
(
    @CompanyID INT
)
AS
BEGIN
    SELECT Product.ProductName, Product.ProductPrice
    FROM Product
    INNER JOIN Ordering ON Product.ProductID = Ordering.ProductID
    WHERE Ordering.CompanyID = @CompanyID;
END;
 go


CREATE PROCEDURE GetDeliveryDetails
(
    @OrderID INT
)
AS
BEGIN
    SELECT Delivery.DeliveryID, Delivery.ShipToCountry, Delivery.ShipToRegion, Delivery.ETD, Delivery.ETA, Delivery.LogisticType, Delivery.ProductTravelTime
    FROM Delivery
    WHERE Delivery.OrderID = @OrderID;
END;
go



CREATE PROCEDURE GetMostOrderedProduct  --This Procedure gets the spesific company's most orderedProduct
(
    @CompanyID INT
)
AS
BEGIN
    SELECT TOP 1 Product.ProductName, COUNT(Product.ProductID) as 'Number of Orders'
    FROM Product
    INNER JOIN Ordering ON Product.ProductID = Ordering.ProductID
    WHERE Ordering.CompanyID = @CompanyID
    GROUP BY Product.ProductName
    ORDER BY COUNT(Product.ProductID) DESC
    
END
go


CREATE PROCEDURE GetEmployeeWithMostSales  --This Procedure Gets employee with The highest total of all the sales
AS
BEGIN
    SELECT TOP 1 Employee.FirstName, Employee.LastName, SUM(Product.ProductPrice * Bill.Volume) as 'Total Order Value'
    FROM Employee
    INNER JOIN Ordering ON Employee.EmployeeID = Ordering.EmployeeID
    INNER JOIN Bill ON Ordering.OrderID = Bill.OrderID
    INNER JOIN Product ON Bill.ProductID = Product.ProductID
    GROUP BY Employee.FirstName, Employee.LastName
    ORDER BY SUM(Product.ProductPrice * Bill.Volume) DESC
    
END;



   INSERT INTO Product(ProductName,Description,ProductPrice)
   Values ('Polypropylene Homopolymer', 'A type of polypropylene with a single type of monomer', 100),
('Impact Copolymer', 'A type of polypropylene with multiple types of monomers for added strength', 150),
('Random Copolymer', 'A type of polypropylene with randomly arranged monomers', 120),
('Methanol', 'A type of alcohol used as a solvent and fuel', 80),
('Esters', 'A class of organic compounds used in a variety of applications including flavors, fragrances, and plastics', 90),
('Amines', 'Organic compounds containing nitrogen atoms that are used in the production of dyes, pharmaceuticals, and other chemicals', 110),
('Carboxylic Acids', 'Organic compounds containing a carboxyl group that are used in the production of plastics, dyes, and other chemicals', 130),
('Higher Aldehydes', 'Organic compounds containing an aldehyde group that are used in the production of flavors, fragrances, and other chemicals', 140),
('Specialty Derivatives', 'Customized derivatives for specific applications', 160),
('Polyols', 'Organic compounds containing multiple hydroxyl groups that are used in the production of polyurethanes and other materials', 170),
('Specialty Esters', 'Customized esters for specific applications', 180),
('HDPE', 'High-density polyethylene, a strong and durable plastic', 190),
('LLDPE', 'Linear low-density polyethylene, a flexible and impact-resistant plastic', 200),
('Polypropylene Homopolymer', 'A type of polypropylene with a single type of monomer', 210),
('Polypropylene Random Copolymer', 'A type of polypropylene with randomly arranged monomers', 220),
('Butanol', 'A type of alcohol used as a solvent and fuel', 230),
('Acetone', 'A type of ketone used as a solvent and in the production of plastics, fibers, and resins', 240),
('Ethyl Acetate', 'A type of ester used as a solvent and in the production of paints, inks, and other coatings', 250),
('Methyl Amine', 'An organic compound containing nitrogen atoms that is used in the production of pharmaceuticals, dyes, and other chemicals', 260),
('Formic Acid', 'A type of carboxylic acid used in the production of textiles, leather, and other materials', 270),
('Acetaldehyde', 'An aldehyde used in the production of flavors, fragrances, and other chemicals', 280),
('Specialty Derivatives', 'Customized derivatives for specific applications', 290),
('Glycerol', 'A type of polyol used in the production of explosives, plastics, and other materials', 300),
('Methyl Ester', 'A type of ester used as a biofuel and in the production of lubricants, surfactants, and other chemicals', 310),
('Polypropylene Impact Copolymer', 'A type of polypropylene with multiple types of monomers for added strength', 320);

 set identity_insert CustomerCompany on
   INSERT INTO CustomerCompany (CompanyID, CName, contactMail, phoneNumber, totalPurchase) 
   VALUES  (1, 'Polymer Solutions Inc.', 'info@polymersolutions.com', 5551234, 500000),
(2, 'Chemical Suppliers Inc.', 'info@chemsuppliers.com', 5551235, 450000),
(3, 'Plastic Products Co.', 'info@plasticprodco.com', 5551236, 400000),
(4, 'Industrial Materials Inc.', 'info@industrialmaterials.com', 5551237, 350000),
(5, 'Polymer Resources Inc.', 'info@polymerresources.com', 5551238, 300000),
(6, 'Chemical Distributors Inc.', 'info@chemdistrib.com', 5551239, 250000),
(7, 'Plastic Materials Co.', 'info@plasticmaterials.com', 5551240, 200000),
(8, 'Industrial Chemicals Inc.', 'info@industrialchemicals.com', 5551241, 150000),
(9, 'Polymer Technologies Inc.', 'info@polymertech.com', 5551242, 100000),
(10, 'Chemical Enterprises Inc.', 'info@chemicalenterprises.com', 5551243, 50000),
(11, 'Plastic Solutions Co.', 'info@plasticsolutions.com', 5551244, 40000),
(12, 'Industrial Plastics Inc.', 'info@industrialplastics.com', 5551245, 30000),
(13, 'Polymer Associates Inc.', 'info@polymerassociates.com', 5551246, 20000),
(15, 'Chemical Solutions Inc.', 'info@chemsolutions.com', 5551247, 10000),
(16, 'Plastic Industries Co.', 'info@plasticindustries.com', 5551248, 5000),
(17, 'Industrial Polymers Inc.', 'info@industrialpolymers.com', 5551249, 4000),
(18, 'Polymer Specialties Inc.', 'info@polymerspecialties.com', 5551250, 3000),
(19, 'Chemical Products Inc.', 'info@chemicalproducts.com', 5551251, 2000),
(20, 'Plastic Components Co.', 'info@plasticcomponents.com', 5551252, 1000),
(21, 'Industrial Resins Inc.', 'info@industrialresins.com', 5551253, 500),
(22, 'Polymer Solutions LLC', 'info@polymersolutionsllc.com', 5551254, 400),
(23, 'Chemical Suppliers LLC', 'info@chemsuppliersllc.com', 5551255, 300),
(24, 'Plastic Products Inc.', 'info@plasticproductsinc.com', 5551256, 200),
(25, 'Industrial Materials LLC', 'info@industrialmaterialsllc.com', 5551257, 100),
(26, 'Polymer Resources LLC', 'info@polymerresourcesllc.com', 5551258, 50);
 
 INSERT INTO Company(CName,Address,Website)
 VALUES ('OQ Inc.', 'Muscat Grand Mall, Tilal properties
Dohat Al Adab Street, Ghubra, Muscat OM' , 'https://oq.com/en');


 INSERT INTO Employee(CName, FirstName, LastName, emailAddress, phoneNumber,salary,gender,dateOfBirth)
 VALUES ('OQ Inc.', 'Ahmet', 'Yýlmaz', 'ahmet.yilmaz@oqinc.com', '5551234569', 35000, 'M', '1998-06-01'),
('OQ Inc.', 'Ayþe', 'Kaya', 'ayse.kaya@oqinc.com', '5551234570', 30000, 'F', '1995-09-01'),
('OQ Inc.', 'Mehmet', 'Öztürk', 'mehmet.ozturk@oqinc.com', '5551234571', 25000, 'M', '1999-03-01'),
('OQ Inc.', 'Elif', 'Çetin', 'elif.cetin@oqinc.com', '5551234572', 20000, 'F', '1997-12-01'),
('OQ Inc.', 'Ali', 'Köse', 'ali.kose@oqinc.com', '5551234573', 15000, 'M', '2000-05-01'),
('OQ Inc.', 'Emel', 'Yýldýz', 'emel.yildiz@oqinc.com', '5551234574', 10000, 'F', '1996-08-01'),
('OQ Inc.', 'Murat', 'Özdemir', 'murat.ozdemir@oqinc.com', '5551234575', 9000, 'M', '1995-02-01'),
('OQ Inc.', 'Can', 'Tekin', 'can.tekin@oqinc.com', '5551234577', 7000, 'M', '1997-07-01'),
('OQ Inc.', 'Nurcan', 'Doðan', 'nurcan.dogan@oqinc.com', '5551234578', 6000, 'F', '1998-01-01'),
('OQ Inc.', 'Fatih', 'Çakýr', 'fatih.cakir@oqinc.com', '5551234579', 5000, 'M', '1999-04-01'),
('OQ Inc.', 'Zeynep', 'Güler', 'zeynep.guler@oqinc.com', '5551234580', 4000, 'F', '1996-11-01'),
('OQ Inc.', 'Emre', 'Özkan', 'emre.ozkan@oqinc.com', '5551234581', 3000, 'M', '2000-09-01'),
('OQ Inc.', 'Selin', 'Yýlmaz', 'selin.yilmaz@oqinc.com', '5551234582', 2500, 'F', '1998-03-01'),
('OQ Inc.', 'Deniz', 'Çetin', 'deniz.cetin@oqinc.com', '5551234583', 2000, 'M', '1997-06-01'),
('OQ Inc.', 'Nilüfer', 'Aksoy', 'nilufer.aksoy@oqinc.com', '5551234584', 1500, 'F', '1999-07-01'),
('OQ Inc.', 'Onur', 'Dursun', 'onur.dursun@oqinc.com', '5551234585', 1000, 'M', '1996-02-01'),
('OQ Inc.', 'Ezgi', 'Güngör', 'ezgi.gungor@oqinc.com', '5551234586', 900, 'F', '1998-05-01'),
('OQ Inc.', 'Mustafa', 'Kaçar', 'mustafa.kacar@oqinc.com', '5551234587', 800, 'M', '1995-10-01'),
('OQ Inc.', 'Zeynep', 'Öztürk', 'zeynep.ozturk@oqinc.com', '5551234588', 700, 'F', '1997-04-01'),
('OQ Inc.', 'Ýbrahim', 'Yýldýz', 'ibrahim.yildiz@oqinc.com', '5551234589', 600, 'M', '1999-08-01'),
('OQ Inc.', 'Sena', 'Çetinkaya', 'sena.cetinkaya@oqinc.com', '5551234590', 500, 'F', '1997-12-01'),
('OQ Inc.', 'Erhan', 'Özkan', 'erhan.ozkan@oqinc.com', '5551234591', 400, 'M', '1998-09-01'),
('OQ Inc.', 'Aslý', 'Gümüþ', 'asli.gumus@oqinc.com', '5551234592', 300, 'F', '1996-06-01'),
('OQ Inc.', 'Bülent', 'Özdemir', 'bulent.ozdemir@oqinc.com', '5551234593', 200, 'M', '1997-03-01'),
('OQ Inc.', 'Merve', 'Kaya', 'merve.kaya@oqinc.com', '5551234594', 100, 'F', '1999-11-01');


INSERT INTO Team (TName)
VALUES
('Team Alpha'),
('Team Beta'),
('Team Theta'),
('Team Delta'),
('Team Charlie');

INSERT INTO Manager(ManagerID,TeamID)
VALUES ('1' ,'1'),
('2','2'),
('3','3'),  ('4','4') ,('5','5');


INSERT INTO Stuff(StuffID,TeamID)
VALUES ('6','1'), ('11','1'), ('16','1'), ('21','1'),
       ('7','2'), ('12','2'), ('17','2'), ('22','2'),
	   ('8','3'), ('13','3'), ('18','3'), ('23','3'),
	   ('9','4'), ('14','4'), ('19','4'), ('24','4'),
	   ('10','5'), ('15','5'), ('20','5'), ('25','5');

INSERT INTO Ordering(CompanyID,ProductID,EmployeeID)
VALUES ('7', '11', '22'), ('9', '24', '6'), ('2', '3', '9'), ('10', '8', '20'),
('6', '24', '19'), ('23', '1', '5'), ('22', '6', '4'), ('18', '14', '16'),
('17', '4', '10'), ('21', '9', '2'), ('25', '20', '16'), ('7', '12', '15'),
('17', '2', '23'), ('1', '21', '18'), ('3', '5', '25'), ('8', '22', '11'),
('6', '19', '9'), ('12', '1', '24'), ('15', '10', '4'), ('7', '16', '5'), ('18', '14', '20'),
('2', '24', '23'), ('13', '19', '1'), ('9', '3', '11'), ('17', '22', '15'), ('10', '8', '25'), ('6', '4', '12'), 
('21', '13', '5'), ('20', '2', '7'), ('1', '16', '23'), ('24', '19', '17'), ('5', '3', '15'),
('5', '18', '9'), ('10', '11', '21'), ('8', '1', '25'), ('4', '6', '20'),
('2', '7', '19'),
('23', '12', '14'),
('13', '16', '3'),
('17', '15', '9'),
('5', '24', '22'),
('6', '11', '18'),
('1', '20', '2'),
('25', '3', '7'),
('9', '8', '23'),
('22', '14', '21'),
('10', '19', '16'), ('4', '17', '12'),
('15', '13', '5'), ('2', '6', '24');

set identity_insert Bill on
INSERT INTO Bill (OrderID, Volume, PaymentTerms)
VALUES
  ( 1, 10, '30 days'),
  ( 2, 15, '35 days'),
  ( 3, 20, '40 days'),
  ( 4, 25, '45 days'),
  ( 5, 30, '30 days'),
  ( 6, 35, '35 days'),
  ( 7, 40, '40 days'),
  ( 8, 45, '45 days'),
  ( 9, 50, '30 days'),
  ( 10, 55, '35 days'),
  ( 11, 60, '40 days'),
  ( 12, 65, '45 days'),
  ( 13, 70, '30 days'),
  ( 14, 75, '35 days'),
  ( 15, 80, '40 days'),
  ( 16, 85, '45 days'),
  ( 17, 90, '30 days'),
  (18, 95, '35 days'),
  ( 19, 100, '40 days'),
  ( 20, 105, '45 days'),
  ( 21, 110, '30 days'),
  ( 22, 115, '35 days'),
  ( 23, 120, '40 days'),
  ( 24, 125, '45 days'),
  (25, 130, '30 days'),
  ( 26, 135, '35 days'),
  ( 27, 140, '40 days'),
  ( 28, 145, '25 days'),
  ( 29, 150, '45 days'),
  ( 30, 155, '30 days'),
  ( 31, 160, '35 days'),
  (32, 165, '40 days'),
  (33, 170, '45 days'),
  ( 34, 175, '30 days'),
  ( 35, 180, '35 days'),
  ( 36, 185, '40 days'),
  ( 37, 190, '45 days'),
  (38, 195, '30 days'),
  ( 39, 200, '35 days'),
  (40, 205, '40 days'),
  ( 41, 210, '45 days'),
  ( 42, 215, '30 days'),
  ( 43, 220, '35 days'),
  ( 44, 225, '40 days'),
  ( 45, 230, '45 days'),
  ( 46, 235, '30 days'),
  ( 47, 240, '35 days'),
  ( 48, 245, '40 days'),
  ( 49, 250, '45 days'),
  (50, 255, '30 days');



UPDATE b     
SET b.ProductID = (SELECT o.ProductID FROM Ordering o WHERE o.OrderID = b.Bill_ID)
FROM Bill b;

INSERT INTO Delivery (OrderID, ShipToCountry, ShipToRegion, ETD, ETA, LogisticType) 
VALUES  (1, 'United States', 'New York', '2022-01-01', '2022-01-05', 'Truck'),
  (2, 'United States', 'California', '2022-01-02', '2022-01-07', 'Air'),
  (3, 'United States', 'Texas', '2022-01-03', '2022-01-09', 'Sea'),
  (4, 'United States', 'Florida', '2022-01-04', '2022-01-11', 'Truck'),
  (5, 'United States', 'Illinois', '2022-01-05', '2022-01-13', 'Truck'),
  (6, 'United States', 'Pennsylvania', '2022-01-06', '2022-01-15', 'Truck'),
  (7, 'United States', 'Ohio', '2022-01-07', '2022-01-17', 'Air'),
  (8, 'United States', 'Georgia', '2022-01-08', '2022-01-19', 'Truck'),
  (9, 'United States', 'North Carolina', '2022-01-09', '2022-01-21', 'Sea'),
  (10, 'United States', 'Michigan', '2022-01-10', '2022-01-23', 'Air'),
  (11, 'United States', 'New Jersey', '2022-01-11', '2022-01-25', 'Truck'),
  (12, 'United States', 'Virginia', '2022-01-12', '2022-01-27', 'Air'),
  (13, 'United States', 'Washington', '2022-01-13', '2022-01-29','Truck'),
  (14, 'Canada', 'Ontario', '2022-01-14', '2022-01-31', 'Air'),
  (15, 'Canada', 'British Columbia', '2022-01-15', '2022-02-02', 'Truck'),
  (16, 'Canada', 'Quebec', '2022-01-16', '2022-02-04', 'Air'),
  (17, 'Mexico', 'Mexico City', '2022-01-17', '2022-02-06', 'Truck'),
  (18, 'Mexico', 'Guadalajara', '2022-01-18', '2022-02-08', 'Truck'),
  (19, 'Mexico', 'Monterrey', '2022-01-19', '2022-02-10', 'Truck'),
  (20, 'Brazil', 'São Paulo', '2022-01-20', '2022-02-12', 'Truck'),
  (21, 'Brazil', 'Rio de Janeiro', '2022-01-21', '2022-02-14', 'Air'),
  (22, 'Brazil', 'Belo Horizonte', '2022-01-22', '2022-02-16', 'Air'),
  (23, 'Argentina', 'Buenos Aires', '2022-01-23', '2022-02-18', 'Truck'),
  (24, 'Argentina', 'Córdoba', '2022-01-24', '2022-02-20', 'Truck'),
  (25, 'Argentina', 'Rosario', '2022-01-25', '2022-02-22', 'Truck'),
  (26, 'Argentina', 'Mendoza', '2022-01-26', '2022-02-24', 'Air'),
  (27, 'Argentina', 'La Plata', '2022-01-27', '2022-02-26', 'Air'),
  (28, 'Argentina', 'Mar del Plata', '2022-01-28', '2022-02-28', 'Truck'),
  (48, 'Turkey', 'Istanbul', '2022-06-01', '2022-06-05', 'Air'),
  (47, 'USA', 'New York', '2022-07-02', '2022-07-07', 'Sea'),
  (46, 'Russia', 'Moscow', '2022-08-03', '2022-08-08', 'Air'),
  (45, 'China', 'Beijing', '2022-09-04', '2022-09-09', 'Sea'),
  (44, 'UK', 'London', '2022-10-05', '2022-10-10', 'Air'),
  (43, 'Japan', 'Tokyo', '2022-11-06', '2022-11-11', 'Truck'),
  (42, 'France', 'Paris', '2022-12-07', '2022-12-12', 'Air'),
  (41, 'Germany', 'Berlin', '2023-01-08', '2023-01-13', 'Truck'),
  (40, 'Italy', 'Rome', '2023-02-09', '2023-02-14', 'Truck'),
  (39, 'Spain', 'Madrid', '2023-03-10', '2023-03-15', 'Truck'),
  (38, 'Brazil', 'Rio de Janeiro', '2023-04-11', '2023-04-16', 'Air'),
  (37, 'Argentina', 'Buenos Aires', '2023-05-12', '2023-05-17', 'Sea'),
  (36, 'Mexico', 'Mexico City', '2023-06-13', '2023-06-18', 'Air'),
  (35, 'Colombia', 'Bogota', '2023-07-14', '2023-07-19', 'Sea'),
  (34, 'Peru', 'Lima', '2023-08-15', '2023-08-20', 'Air'),
  (33, 'Chile', 'Santiago', '2023-09-16', '2023-09-21', 'Sea'),
  (32, 'Venezuela', 'Caracas', '2023-10-17', '2023-10-22', 'Air'),
  (31, 'Ecuador', 'Quito', '2023-11-18', '2023-11-23', 'Sea'),
  (30, 'Uruguay', 'Montevideo', '2023-12-19', '2023-12-24', 'Air'),
  (29, 'Paraguay', 'Asuncion', '2024-01-20', '2024-01-25', 'Sea'),
  (49, 'Dominican Republic', 'Santo Domingo', '2024-10-29', '2024-11-03', 'Air'),
  (50, 'Jamaica', 'Kingston', '2024-11-30', '2024-12-05', 'Sea');
  go

  CREATE VIEW ProductSales AS
SELECT p.ProductID, p.ProductName, SUM(b.Volume) AS TotalVolume, SUM(b.Volume * p.ProductPrice) AS TotalRevenue, AVG(p.ProductPrice) AS AveragePricePerUnit
FROM Product p
JOIN Ordering o ON p.ProductID = o.ProductID
JOIN Bill b ON o.OrderID = b.OrderID
GROUP BY p.ProductID, p.ProductName;
go






CREATE VIEW DeliveryStatus AS
SELECT d.DeliveryID, d.OrderID, p.ProductName, d.ShipToCountry, d.ShipToRegion, d.ETD, d.ETA, 
    CASE WHEN d.ETA > GETDATE() THEN 'In Progress' ELSE 'Completed' END AS Status
FROM Delivery d
JOIN Ordering o ON d.OrderID = o.OrderID
JOIN Product p ON o.ProductID = p.ProductID;
go


CREATE VIEW OrderSummary AS
SELECT o.OrderID, p.ProductName, cc.CName AS CustomerCompanyName, o.orderDate, b.Volume * p.ProductPrice AS TotalPrice
FROM Ordering o
JOIN Product p ON o.ProductID = p.ProductID
JOIN CustomerCompany cc ON o.CompanyID = cc.CompanyID
JOIN Bill b ON o.OrderID = b.OrderID;
go



CREATE VIEW customer_order_totals
AS
    SELECT TOP 100 c.CName, COUNT(o.OrderID) AS NumOrders, SUM(b.Volume * p.ProductPrice) AS OrderTotal
    FROM CustomerCompany c
    INNER JOIN Ordering o ON c.CompanyID = o.CompanyID
    INNER JOIN Bill b ON o.OrderID = b.OrderID
    INNER JOIN Product p ON b.ProductID = p.ProductID
    
	GROUP BY c.CName
	Order By OrderTotal desc
go
CREATE TRIGGER tr_ReverseInsert
ON Bill
AFTER INSERT
AS
BEGIN
    DECLARE @Bill_ID INT, @OrderID INT;

    SELECT @Bill_ID = Bill_ID, @OrderID = OrderID
    FROM inserted;

    IF NOT EXISTS (SELECT 1 FROM Ordering WHERE OrderID = @Bill_ID)
    BEGIN
        RAISERROR ('Error: OrderID does not match Bill_ID', 16, 1);
        ROLLBACK TRANSACTION;
    END
END


INSERT INTO Ordering(CompanyID,ProductID,EmployeeID)
VALUES ('8', '12', '23')
Select * From Ordering
Select * From CustomerCompany where CompanyID=8

INSERT INTO Bill (OrderID, Volume)
VALUES ('52' , '4')