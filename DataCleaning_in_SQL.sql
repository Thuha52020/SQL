---1. Create a duplicate table to avoid losing original data

SELECT * INTO database_staging 
FROM data_base;

-----------------------------------------------------------------------------------------------------------------------------------------

---2. Standardize Date Format of the SaleDate Column

SELECT * FROM database_staging; 

SELECT SaleDate, CONVERT (DATE, SaleDate) 
FROM database_staging; 

--Create a new column with the standard date data format

ALTER TABLE database_staging
ADD SaleDateConverted DATE;

UPDATE database_staging
SET SaleDateConverted = CONVERT(DATE,SaleDate);

-----------------------------------------------------------------------------------------------------------------------------------------

---3. Normalize missing data for the PropertyAddress column

SELECT PropertyAddress 
FROM database_staging 
WHERE PropertyAddress is NULL;

--Data with the same ParcelID number will have the same address, fill in missing addresses based on ParcelID

SELECT a.ParcelID, 
       b.ParcelID, 
       a.PropertyAddress, 
       b.PropertyAddress, 
       ISNULL(a.PropertyAddress,b.PropertyAddress) 
FROM database_staging a 
JOIN database_staging b 
ON a.ParcelID = b.ParcelID 
AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress is NULL;

--Update missing data to the table

UPDATE a 
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM database_staging a 
JOIN database_staging b 
ON a.ParcelID = b.ParcelID 
AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress is NULL;

-----------------------------------------------------------------------------------------------------------------------------------------

---4. Split PropertyAddress, OwnerAddress Column to Address column, City column ( Tách cột PropertyAddress thành Address, city, state)

--Split PropertyAddress Column to Address and City

SELECT PropertyAddress 
FROM database_staging;

SELECT PropertyAddress, SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) AS Address,
       SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) AS City
FROM database_staging;

-- Insert columns SplitAddress and SplitCity into the table

ALTER TABLE database_staging
ADD SplitAddress NVARCHAR(255);

UPDATE database_staging
SET SplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1);

ALTER TABLE database_staging
ADD City NVARCHAR(255);

UPDATE database_staging
SET City = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress));

--Split OwnerAddress Column to Address, City and State

SELECT OwnerAddress, PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3), 
       PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
       PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
FROM database_staging;

--Insert columns OwnerSplitAddress, OwnerSplitCity, OwnerSplitState into the table

ALTER TABLE database_staging
ADD OwnerSplitAddress NVARCHAR(255);

UPDATE database_staging
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3);

ALTER TABLE database_staging
ADD OwnerSplitCity NVARCHAR(255);

UPDATE database_staging
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2);

ALTER TABLE database_staging
ADD OwnerSplitState NVARCHAR(255);

UPDATE database_staging
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

-----------------------------------------------------------------------------------------------------------------------------------------

---5. Change Y and N to 'Yes' and 'No' in SoldAsVacant column

SELECT SoldAsVacant,
  CASE 
   WHEN  SoldAsVacant = 'Y' THEN 'Yes'
   WHEN SoldAsVacant = 'N' THEN 'No' 
   ELSE SoldAsVacant
  END
FROM database_staging;

--Update data into the table

UPDATE database_staging 
SET SoldAsVacant = CASE 
                      WHEN SoldAsVacant = 'Y' THEN 'Yes'
                      WHEN SoldAsVacant = 'N' THEN 'No' 
                      ELSE SoldAsVacant
                   END
FROM database_staging;

-----------------------------------------------------------------------------------------------------------------------------------------

---6. Remove duplicate values

-- Find duplicate values

WITH duplicate AS 
 (
 SELECT ROW_NUMBER() OVER(PARTITION BY ParcelID, 
                                        PropertyAddress, 
                                        SaleDate, 
                                        SalePrice, 
                                        LegalReference 
			               ORDER BY UniqueID) AS Row_num, * 
  FROM database_staging
  )
SELECT * FROM duplicate
WHERE Row_num > 1;

-- Remove duplicate values

WITH duplicate AS 
(
SELECT ROW_NUMBER() OVER(PARTITION BY ParcelID, 
                                      PropertyAddress, 
                                      SaleDate, 
                                      SalePrice, 
                                      LegalReference  
						 ORDER BY UniqueID) AS Row_num, * 
FROM database_staging
)
DELETE FROM duplicate
WHERE Row_num > 1;

-----------------------------------------------------------------------------------------------------------------------------------------
---7. Delete Unused Columns

ALTER TABLE database_staging 
DROP COLUMN PropertyAddress,
            SaleDate, 
            OwnerAddress, 
            TaxDistrict;