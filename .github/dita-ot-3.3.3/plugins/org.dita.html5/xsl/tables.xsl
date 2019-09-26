<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                xmlns:table="http://dita-ot.sourceforge.net/ns/201007/dita-ot/table"
                version="2.0"
                exclude-result-prefixes="xs dita-ot dita2html ditamsg table">

  <!-- XML Exchange Table Model Document Type Definition default is all -->
  <xsl:variable name="table.frame-default" select="'all'"/>
  <!-- XML Exchange Table Model Document Type Definition default is 1 -->
  <xsl:variable name="table.rowsep-default" select="'0'"/>
  <!-- XML Exchange Table Model Document Type Definition default is 1 -->
  <xsl:variable name="table.colsep-default" select="'0'"/>
  
  <xsl:template match="*[contains(@class, ' topic/table ')]" mode="generate-table-summary-attribute">
    <!-- Override this to use a local convention for setting table's @summary attribute,
         until OASIS provides a standard mechanism for setting. -->
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/tgroup ')]" name="topic.tgroup">
    <xsl:variable name="totalwidth" as="xs:double">
      <xsl:variable name="relative-widths" as="xs:double*">
        <xsl:for-each select="*[contains(@class, ' topic/colspec ')][contains(@colwidth, '*')]">
          <xsl:sequence select="xs:double(translate(@colwidth, '*', ''))"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:sequence select="sum($relative-widths)"/>
    </xsl:variable>
    <xsl:if test="exists(*[contains(@class, ' topic/colspec ')])">
      <colgroup>
        <xsl:apply-templates select="*[contains(@class, ' topic/colspec ')]">
          <xsl:with-param name="totalwidth" select="$totalwidth"/>
        </xsl:apply-templates>
      </colgroup>
    </xsl:if>
    <xsl:apply-templates select="* except *[contains(@class, ' topic/colspec ')]">
      <xsl:with-param name="totalwidth" select="$totalwidth"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/colspec ')]">
    <xsl:param name="totalwidth" as="xs:double"/>
    <xsl:variable name="width" as="xs:string?">
      <xsl:choose>
        <xsl:when test="empty(@colwidth)"/>
        <xsl:when test="contains(@colwidth, '*')">
          <xsl:value-of select="concat((xs:double(translate(@colwidth, '*', '')) div $totalwidth) * 100, '%')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@colwidth"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <col>
      <xsl:if test="exists($width)">
        <xsl:attribute name="style" select="concat('width:', $width)"/>
      </xsl:if>
    </col>
  </xsl:template>
  
  <xsl:template name="doentry">
    <xsl:variable name="this-colname" select="@colname"/>
    <!-- Rowsep/colsep: Skip if the last row or column. Only check the entry and colsep;
      if set higher, will already apply to the whole table. -->
    <xsl:variable name="row" select=".." as="element()"/>
    <xsl:variable name="body" select="../.." as="element()"/>
    <xsl:variable name="group" select="../../.." as="element()"/>
    <xsl:variable name="colspec" select="../../../*[contains(@class, ' topic/colspec ')][@colname and @colname = $this-colname]" as="element()"/>
    <xsl:variable name="table" select="../../../.." as="element()"/>
    
    <xsl:variable name="framevalue">
      <xsl:choose>
        <xsl:when test="$table/@frame and $table/@frame != ''">
          <xsl:value-of select="$table/@frame"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$table.frame-default"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>  
    <xsl:variable name="rowsep" as="xs:integer">
      <xsl:variable name="last-row" select="(../../../*/*[contains(@class, ' topic/row ')])[last()]" as="element()"/>
      <xsl:choose>
        <!-- If there are more rows, keep rows on -->      
        <xsl:when test="not(. &lt;&lt; $last-row)">
          <xsl:choose>
            <xsl:when test="$framevalue = 'all' or $framevalue = 'bottom' or $framevalue = 'topbot'">1</xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="@rowsep"><xsl:value-of select="@rowsep"/></xsl:when>
        <xsl:when test="$row/@rowsep"><xsl:value-of select="$row/@rowsep"/></xsl:when>
        <xsl:when test="$colspec/@rowsep"><xsl:value-of select="$colspec/@rowsep"/></xsl:when>
        <xsl:when test="$table/@rowsep"><xsl:value-of select="$table/@rowsep"/></xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$table.rowsep-default"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="colsep" as="xs:integer">
      <xsl:choose>
        <!-- If there are more columns, keep rows on -->
        <xsl:when test="empty(following-sibling::*)">
          <xsl:choose>
            <xsl:when test="$framevalue = 'all' or $framevalue = 'sides'">1</xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="@colsep"><xsl:value-of select="@colsep"/></xsl:when>
        <xsl:when test="$colspec/@colsep"><xsl:value-of select="$colspec/@colsep"/></xsl:when>
        <xsl:when test="$table/@colsep"><xsl:value-of select="$table/@colsep"/></xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$table.colsep-default"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="firstcol" as="xs:boolean" select="$table/@rowheader = 'firstcol' and @dita-ot:x = '1'"/>  
    
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class">
        <xsl:if test="$firstcol">firstcol </xsl:if>
        <xsl:choose>
          <xsl:when test="$rowsep = 0 and $colsep = 0">nocellnorowborder</xsl:when>
          <xsl:when test="$rowsep = 1 and $colsep = 0">row-nocellborder</xsl:when>
          <xsl:when test="$rowsep = 0 and $colsep = 1">cell-norowborder</xsl:when>
          <xsl:when test="$rowsep = 1 and $colsep = 1">cellrowborder</xsl:when>
        </xsl:choose>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:choose>
      <xsl:when test="@id">
        <xsl:call-template name="setid"/>    
      </xsl:when>
      <xsl:when test="$firstcol">
        <xsl:attribute name="id" select="generate-id(.)"/>
      </xsl:when>
    </xsl:choose>
    <xsl:if test="@morerows">
      <xsl:attribute name="rowspan"> <!-- set the number of rows to span -->
        <xsl:value-of select="@morerows + 1"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@dita-ot:morecols"> <!-- get the number of columns to span from the specified named column values -->
      <xsl:attribute name="colspan" select="@dita-ot:morecols + 1"/>
    </xsl:if>
    <!-- If align is specified on a colspec, that takes priority over tgroup -->
    
    <!-- If align is locally specified, that takes priority over all -->
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:variable name="align" as="xs:string?">
          <xsl:choose>
           <xsl:when test="@align">
             <xsl:value-of select="@align"/>
           </xsl:when>
            <xsl:when test="$group/@align">
              <xsl:value-of select="$group/@align"/>
            </xsl:when>
            <xsl:when test="$colspec/@align">
              <xsl:value-of select="$colspec/@align"/>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:if test="exists($align)">
          <xsl:text>text-align:</xsl:text>
          <xsl:value-of select="$align"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
        <xsl:variable name="valign" as="xs:string?">
          <xsl:choose>
           <xsl:when test="@valign">
             <xsl:value-of select="@valign"/>
           </xsl:when>
           <xsl:when test="$row/@valign">
             <xsl:value-of select="$row/@valign"/>
           </xsl:when>
            <xsl:when test="$body/@valign">
              <xsl:value-of select="$body/@valign"/>
            </xsl:when>
            <xsl:otherwise>top</xsl:otherwise>
         </xsl:choose>
        </xsl:variable>
        <xsl:if test="exists($valign)">
          <xsl:text>vertical-align:</xsl:text>
          <xsl:value-of select="$valign"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:variable name="char" as="xs:string?">
      <xsl:choose>
        <xsl:when test="@char">
          <xsl:value-of select="@char"/>
        </xsl:when>
        <xsl:when test="$colspec/@char">
          <xsl:value-of select="$colspec/@char"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="$char">
      <xsl:attribute name="char" select="$char"/>
    </xsl:if>
    <xsl:variable name="charoff" as="xs:string?">
      <xsl:choose>
        <xsl:when test="@charoff">
          <xsl:value-of select="@charoff"/>
        </xsl:when>
        <xsl:when test="$colspec/@charoff">
          <xsl:value-of select="$colspec/@charoff"/>
        </xsl:when>
      </xsl:choose>  
    </xsl:variable>
    <xsl:if test="$charoff">
      <xsl:attribute name="charoff" select="$charoff"/>
    </xsl:if>
  
    <xsl:choose>
      <!-- When entry is in a thead, output the ID -->
      <xsl:when test="$body/self::*[contains(@class, ' topic/thead ')]">
        <xsl:attribute name="id" select="dita-ot:generate-html-id(.)"/>
      </xsl:when>
      <!-- otherwise, add @headers if needed -->
      <xsl:otherwise>
        <xsl:call-template name="add-headers-attribute"/>
      </xsl:otherwise>
    </xsl:choose>
  
    <!-- Add any flags from tgroup, thead or tbody, and row -->
    <xsl:apply-templates select="$group/*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="$body/*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="$row/*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:choose>
      <!-- When entry is empty, output a blank -->
      <xsl:when test="not(*|text()|processing-instruction())">
        <xsl:text>&#160;</xsl:text>  <!-- nbsp -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="$row/*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="$body/*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="$group/*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- Find the end column of a cell. If the cell does not span any columns,
       the end position is the same as the start position. -->
  <!-- DEPRECATED since 3.3: use table:find-entry-end-column -->
  <xsl:template name="find-entry-end-position">
    <xsl:param name="startposition" select="0"/>
    <xsl:choose>
      <xsl:when test="@nameend">
        <xsl:value-of select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = current()/@nameend]/preceding-sibling::*[contains(@class, ' topic/colspec ')])+1)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$startposition"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Check <thead> entries, and return IDs for those which match the desired column -->
  <!-- DEPRECATED since 3.3: use table:get-matching-thead-headers -->
  <xsl:template match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="findmatch">
    <xsl:param name="startmatch" select="1"/>  <!-- start column of the tbody cell -->
    <xsl:param name="endmatch" select="1"/>    <!-- end column of the tbody cell -->
    <xsl:variable name="entrystartpos" select="@dita-ot:x"/>         <!-- start column of this thead cell -->
    <xsl:variable name="entryendpos" select="table:find-entry-end-column(.)"/>           <!-- end column of this thead cell -->
    <!-- The test cell can be any of the following:
         * completely before the header range (ignore id)
         * completely after the header range (ignore id)
         * completely within the header range (save id)
         * partially before, partially within (save id)
         * partially within, partially after (save id)
         * completely surrounding the header range (save id) -->
    <xsl:choose>
      <!-- Ignore this header cell if it  starts after the tbody cell we are testing -->
      <xsl:when test="number($endmatch) &lt; number($entrystartpos)"/>
      <!-- Ignore this header cell if it ends before the tbody cell we are testing -->
      <xsl:when test="number($startmatch) > number($entryendpos)"/>
      <!-- Otherwise, this header lines up with the tbody cell, so use the ID -->
      <xsl:otherwise>
        <xsl:value-of select="dita-ot:generate-html-id(.)"/>
        <xsl:text> </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Check the first column for entries that line up with the test row.
       Any entries that line up need to have the header saved. This template is first
       called with the first entry of the first row in <tbody>. It is called from here
       on the next cell in column one.            -->
  <!-- DEPRECATED since 3.3: use table:get-matching-row-headers -->
  <xsl:template match="*[contains(@class, ' topic/entry ')]" mode="check-first-column">
    <xsl:param name="startMatchRow" select="1"/>   <!-- First row of the tbody cell we are matching -->
    <xsl:param name="endMatchRow" select="1"/>     <!-- Last row of the tbody cell we are matching -->
    <xsl:param name="startCurrentRow" select="1"/> <!-- First row of the column-1 cell we are testing -->
    <xsl:variable name="endCurrentRow">            <!-- Last row of the column-1 cell we are testing -->
      <xsl:choose>
        <!-- If @morerows, the cell ends at startCurrentRow + @morerows. Otherise, start=end. -->
        <xsl:when test="@morerows"><xsl:value-of select="number($startCurrentRow)+number(@morerows)"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="$startCurrentRow"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <!-- When the current column-1 cell ends before the tbody cell we are matching -->
      <xsl:when test="number($endCurrentRow) &lt; number($startMatchRow)">
        <!-- Call this template again with the next entry in column one -->
        <xsl:if test="parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]">
          <xsl:apply-templates select="parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]/*[contains(@class, ' topic/entry ')][1]" mode="check-first-column">
            <xsl:with-param name="startMatchRow" select="$startMatchRow"/>
            <xsl:with-param name="endMatchRow" select="$endMatchRow"/>
            <xsl:with-param name="startCurrentRow" select="number($endCurrentRow)+1"/>
          </xsl:apply-templates>
        </xsl:if>
      </xsl:when>
      <!-- If this column-1 cell starts after the tbody cell we are matching, jump out of recursive loop -->
      <xsl:when test="number($startCurrentRow) > number($endMatchRow)"/>
      <!-- Otherwise, the column-1 cell is aligned with the tbody cell, so save the ID and continue -->
      <xsl:otherwise>
        <xsl:value-of select="if(@id) then dita-ot:generate-html-id(.) else generate-id(.)"/>
        <xsl:text> </xsl:text>
        <!-- If we are not at the end of the tbody cell, and more rows exist, continue testing column 1 -->
        <xsl:if test="number($endCurrentRow) &lt; number($endMatchRow) and
                      parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]">
          <xsl:apply-templates select="parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]/*[contains(@class, ' topic/entry ')][1]" mode="check-first-column">
            <xsl:with-param name="startMatchRow" select="$startMatchRow"/>
            <xsl:with-param name="endMatchRow" select="$endMatchRow"/>
            <xsl:with-param name="startCurrentRow" select="number($endCurrentRow)+1"/>
          </xsl:apply-templates>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Add @headers to cells in the body of a table. -->
  <xsl:template name="add-headers-attribute">
    <!-- Find the IDs of all headers that are aligned above this cell. May contain duplicates due to spanning cells. -->
    <xsl:variable name="all-thead-headers" select="table:get-matching-thead-headers(.)" as="xs:string*"/>
    <!-- Row header should be 0 or 1 today, but future updates may allow multiple -->
    <xsl:variable name="all-row-headers" select="table:get-matching-row-headers(.)" as="xs:string*"/>
    <xsl:if test="exists($all-row-headers) or exists($all-thead-headers)">
      <xsl:attribute name="headers"
        select="distinct-values($all-row-headers), distinct-values($all-thead-headers)"
        separator=" "/>
    </xsl:if>
  </xsl:template>
  
  <!-- ========== "FORMAT" MACROS  - Table title, figure title, InfoNavGraphic ========== -->
  <!--
  | These macros support globally-defined formatting constants for
  | document content.  Some elements have attributes that permit local
  | control of formatting; such logic is part of the pertinent template rule.
  +-->
  
  <!-- table caption -->
  <xsl:template name="place-tbl-lbl">
    <xsl:param name="stringName"/>
    <!-- Number of table/title's before this one -->
    <xsl:variable name="tbl-count-actual" select="count(preceding::*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')])+1"/>
    
    <!-- normally: "Table 1. " -->
    <xsl:variable name="ancestorlang">
      <xsl:call-template name="getLowerCaseLang"/>
    </xsl:variable>
    
    <xsl:choose>
      <!-- title -or- title & desc -->
      <xsl:when test="*[contains(@class, ' topic/title ')]">
        <caption>
          <span class="tablecap">
            <span class="table--title-label">
              <!-- TODO language specific processing should be done with string variables -->
              <xsl:choose>     <!-- Hungarian: "1. Table " -->
                <xsl:when test="$ancestorlang = ('hu', 'hu-hu')">
                  <xsl:value-of select="$tbl-count-actual"/>
                  <xsl:text>. </xsl:text>
                  <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Table'"/>
                  </xsl:call-template>
                  <xsl:text> </xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Table'"/>
                  </xsl:call-template>
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="$tbl-count-actual"/>
                  <xsl:text>. </xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </span>
            <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="tabletitle"/>
            <xsl:if test="*[contains(@class, ' topic/desc ')]">
              <xsl:text>. </xsl:text>
            </xsl:if>
          </span>
          <xsl:for-each select="*[contains(@class, ' topic/desc ')]">
            <span class="tabledesc">
              <xsl:call-template name="commonattributes"/>
              <xsl:apply-templates select="." mode="tabledesc"/>
            </span>
          </xsl:for-each>
        </caption>
      </xsl:when>
      <!-- desc -->
      <xsl:when test="*[contains(@class, ' topic/desc ')]">
        <xsl:for-each select="*[contains(@class, ' topic/desc ')]">
          <span class="tabledesc">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="tabledesc"/>
          </span>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]" mode="tabletitle">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/desc ')]" mode="tabledesc">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/desc ')]" mode="get-output-class">tabledesc</xsl:template>

  <xsl:template match="*" mode="table:common">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates select="." mode="css-class"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/table ')]
    [empty(*[contains(@class,' topic/tgroup ')]/*[contains(@class,' topic/tbody ')]/*[contains(@class,' topic/row ')])]" priority="10"/>
  <xsl:template match="*[contains(@class,' topic/tgroup ')]
    [empty(*[contains(@class,' topic/tbody ')]/*[contains(@class,' topic/row ')])]" priority="10"/>

  <xsl:template match="*[contains(@class,' topic/table ')]" name="topic.table">
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>

    <table>
      <xsl:apply-templates select="." mode="table:common"/>
      <xsl:apply-templates select="." mode="table:title"/>
      <!-- title and desc are processed elsewhere -->
      <xsl:apply-templates select="*[contains(@class, ' topic/tgroup ')]"/>
    </table>

    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/thead ')]" name="topic.thead">
    <thead>
      <xsl:apply-templates select="." mode="table:section"/>
    </thead>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/tbody ')]" name="topic.tbody">
    <tbody>
      <xsl:apply-templates select="." mode="table:section"/>
    </tbody>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/tgroup ')]/*" mode="table:section">
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:apply-templates select="." mode="table:common"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/row ')]" name="topic.row">
    <tr>
      <xsl:apply-templates select="." mode="table:common"/>
      <xsl:apply-templates/>
    </tr>
  </xsl:template>

  <xsl:template match="*[table:is-thead-entry(.)]">
    <th>
      <xsl:apply-templates select="." mode="table:entry"/>
    </th>
  </xsl:template>

  <xsl:template match="*[table:is-tbody-entry(.)][table:is-row-header(.)]">
    <th scope="row">
      <xsl:apply-templates select="." mode="table:entry"/>
    </th>
  </xsl:template>

  <xsl:template match="*[table:is-tbody-entry(.)][not(table:is-row-header(.))]" name="topic.entry">
    <td>
      <xsl:apply-templates select="." mode="table:entry"/>
    </td>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/entry ')]" mode="table:entry">
    <xsl:apply-templates select="." mode="table:common"/>
    <xsl:apply-templates select="." mode="headers"/>
    <xsl:apply-templates select="@morerows, @dita-ot:morecols"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="@pgwide" mode="css-class">
    <xsl:sequence select="dita-ot:css-class(.)"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]" mode="css-class">
    <xsl:apply-templates select="@frame, @pgwide, @scale" mode="#current"/>
  </xsl:template>

  <xsl:template match="@align | @valign | @colsep | @rowsep" mode="css-class">
    <xsl:sequence select="dita-ot:css-class((), .)"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/tgroup ')]/*" mode="css-class">
    <xsl:apply-templates select="@valign" mode="#current"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/row ')]" mode="css-class">
    <xsl:apply-templates select="@rowsep, @valign" mode="#current"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/entry ')]" mode="css-class">
    <xsl:variable name="colsep" as="attribute(colsep)?" select="table:get-entry-colsep(.)"/>
    <xsl:variable name="rowsep" as="attribute(rowsep)?" select="table:get-entry-rowsep(.)"/>
    <xsl:apply-templates mode="#current" select="
      table:get-entry-align(.), $colsep, $rowsep, @valign
    "/>
  </xsl:template>

  <xsl:template match="*[table:is-thead-entry(.)]" mode="headers">
    <xsl:attribute name="id" select="dita-ot:generate-html-id(.)"/>
  </xsl:template>

  <xsl:template match="*[table:is-tbody-entry(.)]" mode="headers">
    <xsl:if test="table:is-row-header(.)">
      <xsl:attribute name="id" select="dita-ot:generate-html-id(.)"/>
    </xsl:if>
    <xsl:call-template name="add-headers-attribute"/>
  </xsl:template>

  <xsl:template match="@morerows">
    <xsl:attribute name="rowspan" select="xs:integer(.) + 1"/>
  </xsl:template>

  <xsl:template match="@dita-ot:morecols">
    <xsl:attribute name="colspan" select="xs:integer(.) + 1"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]" mode="table:title">
    <caption>
      <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="label"/>
      <xsl:apply-templates select="
        *[contains(@class, ' topic/title ')] | *[contains(@class, ' topic/desc ')]
      "/>
    </caption>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]" mode="label">
    <span class="table--title-label">
      <xsl:apply-templates select="." mode="title-number">
        <xsl:with-param name="number" as="xs:integer"
          select="count(key('enumerableByClass', 'topic/table')[. &lt;&lt; current()])"/>
      </xsl:apply-templates>
    </span>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]" mode="title-number">
    <xsl:param name="number" as="xs:integer"/>
    <xsl:sequence select="concat(dita-ot:get-variable(., 'Table'), ' ', $number, '. ')"/>
  </xsl:template>

  <xsl:template mode="title-number" priority="1" match="
    *[contains(@class, ' topic/table ')]
     [dita-ot:get-current-language(.) = ('hu', 'hu-hu')]
   /*[contains(@class, ' topic/title ')]
  ">
    <xsl:param name="number" as="xs:integer"/>
    <xsl:sequence select="concat($number, '. ', dita-ot:get-variable(., 'Table'), ' ')"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]" name="topic.table_title">
    <span>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/desc ')]" name="topic.table_desc">
    <span>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

</xsl:stylesheet>
