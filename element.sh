#!/bin/bash
PSQL="psql -X --username=freecodecamp --dbname=periodic_table --tuples-only -c"

# Main program function
MAIN_PROGRAM() {
  [[ -z $1 ]] && { echo "Please provide an element as an argument."; return; }
  PRINT_ELEMENT "$1"
}

# Print element function
PRINT_ELEMENT() {
  local INPUT=$1
  if [[ ! $INPUT =~ ^[0-9]+$ ]]; then
    ATOMIC_NUMBER=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE symbol='$INPUT' OR name='$INPUT';") | xargs)
  else
    ATOMIC_NUMBER=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE atomic_number=$INPUT;") | xargs)
  fi
  
  if [[ -z $ATOMIC_NUMBER ]]; then
    echo "I could not find that element in the database."
    return
  fi

  # Fetch all required details in one go
  read TYPE_ID NAME SYMBOL ATOMIC_MASS MELTING_POINT_CELSIUS BOILING_POINT_CELSIUS TYPE < <(echo $($PSQL "
    SELECT properties.type_id, elements.name, elements.symbol, properties.atomic_mass, 
           properties.melting_point_celsius, properties.boiling_point_celsius, types.type 
    FROM properties 
    JOIN elements ON properties.atomic_number = elements.atomic_number 
    JOIN types ON properties.type_id = types.type_id 
    WHERE properties.atomic_number = $ATOMIC_NUMBER;") | xargs)

  echo "The element with atomic number $ATOMIC_NUMBER is $NAME ($SYMBOL). It's a $TYPE, with a mass of $ATOMIC_MASS amu. $NAME has a melting point of $MELTING_POINT_CELSIUS Celsius and a boiling point of $BOILING_POINT_CELSIUS Celsius."
}

# Function to fix the database
FIX_DB() {
  echo "Fixing the database..."
  
  # Renaming columns
  $PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
  $PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
  $PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"
  
  # Setting NOT NULL constraints
  $PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"
  
  # Adding UNIQUE constraints and NOT NULL
  $PSQL "ALTER TABLE elements ADD CONSTRAINT unique_symbol UNIQUE(symbol);"
  $PSQL "ALTER TABLE elements ADD CONSTRAINT unique_name UNIQUE(name);"
  $PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
  $PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"

  # Setting up foreign keys
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);"

  # Creating types table
  $PSQL "CREATE TABLE types (type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
  $PSQL "INSERT INTO types(type) SELECT DISTINCT type FROM properties;"
  $PSQL "ALTER TABLE properties ADD COLUMN type_id INT NOT NULL REFERENCES types(type_id);"
  
  # Updating type_id
  $PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE properties.type = types.type);"

  # Updating elements and mass
  $PSQL "UPDATE elements SET symbol=INITCAP(symbol);"
  $PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE FLOAT;"

  # Inserting new elements
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(9, 'F', 'Fluorine'), (10, 'Ne', 'Neon');"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES 
        (9, 'nonmetal', -220, -188.1, 3, 18.998), 
        (10, 'nonmetal', -248.6, -246.1, 3, 20.18);"

  # Deleting non-existent element
  $PSQL "DELETE FROM properties WHERE atomic_number=1000;"
  $PSQL "DELETE FROM elements WHERE atomic_number=1000;"
  
  # Dropping type column from properties
  $PSQL "ALTER TABLE properties DROP COLUMN type;"
}

# Starting program
START_PROGRAM() {
  if [[ $(echo $($PSQL "SELECT COUNT(*) FROM elements WHERE atomic_number=1000;")) -gt 0 ]]; then
    FIX_DB
    clear
  fi
  MAIN_PROGRAM "$1"
}

START_PROGRAM "$1"
