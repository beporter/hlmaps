--------------------------------------------------------------------------------
--                                                                             -
-- hlmaps_create_db.sql  - Creates the base MySQL database for HLmaps          -
--                       - Copyright Scott McCrory                             -
--                       - Distributed under the GPL terms - see docs for info -
--                       - http://hlmaps.sourceforge.net                       -
--                                                                             -
--------------------------------------------------------------------------------
-- CVS $Id$
-------------------------------------------------------------------------------

CREATE DATABASE HLmaps;
USE HLmaps; 
CREATE TABLE maps 
( 
    mapname     VARCHAR(20) NOT NULL, 
    imageurl    VARCHAR(100), 
    downloadurl VARCHAR(100), 
    txtfile     LONGTEXT, 
    popularity  INT UNSIGNED, 
    mapcycle    INT UNSIGNED, 
    size        INT UNSIGNED, 
    moddate     INT UNSIGNED, 
    PRIMARY KEY (mapname) 
);
