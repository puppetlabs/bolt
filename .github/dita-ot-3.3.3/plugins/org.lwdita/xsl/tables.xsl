<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                exclude-result-prefixes="xs dita-ot dita2html">

  <!-- =========== CALS (OASIS) TABLE =========== -->

  <xsl:template match="*[contains(@class, ' topic/table ')]" mode="generate-table-summary-attribute">
    <!-- Override this to use a local convention for setting table's @summary attribute,
         until OASIS provides a standard mechanism for setting. -->
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]" name="topic.table">
    <xsl:call-template name="dotable"/>
  </xsl:template>

  <xsl:template name="dotable">
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <table>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="place-tbl-lbl"/>
      <!-- title and desc are processed elsewhere -->
      <xsl:apply-templates select="*[contains(@class, ' topic/tgroup ')]"/>
    </table>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/tgroup ')]" name="topic.tgroup">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/colspec ')]">
    <col>
      <xsl:if test="@colwidth">
        <xsl:attribute name="width">
          <xsl:choose>
            <xsl:when test="contains(@colwidth, '*')">
              <xsl:value-of select="translate(@colwidth, '*', '')"/>
            </xsl:when>
            <xsl:otherwise>
              <!-- FIXME: calculate relative width -->
              <xsl:value-of select="@colwidth"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@align">
        <xsl:attribute name="align" select="@align"/>
      </xsl:if>
    </col>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/spanspec ')]"></xsl:template>

  <xsl:template match="*[contains(@class, ' topic/thead ')]" name="topic.thead">
    <thead>
      <!-- Get style from parent tgroup, then override with thead if specified locally -->
      <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass"
                           mode="add-ditaval-style"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </thead>
  </xsl:template>

  <!-- Table footer processing. Ignore fall-thru tfoot; process them from the table body -->
  <!--xsl:template match="*[contains(@class, ' topic/tfoot ')]"/-->

  <xsl:template match="*[contains(@class, ' topic/tbody ')]" name="topic.tbody">
    <tbody>
      <!-- Get style from parent tgroup, then override with thead if specified locally -->
      <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass"
                           mode="add-ditaval-style"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </tbody>
  </xsl:template>

  <!-- special mode for table footers -->
  <!--xsl:template match="*[contains(@class, ' topic/tfoot ')]" mode="gen-tfoot">
    <xsl:apply-templates/>
  </xsl:template-->

  <xsl:template match="*[contains(@class, ' topic/row ')]" name="topic.row">
    <tr>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </tr>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/entry ')]" name="topic.entry">
    <tablecell>
      <xsl:call-template name="doentry"/>
    </tablecell>
  </xsl:template>

  <xsl:template name="doentry">
    <xsl:variable name="this-colname" select="@colname"/>
    <!-- Rowsep/colsep: Skip if the last row or column. Only check the entry and colsep;
      if set higher, will already apply to the whole table. -->
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setid"/>
    <xsl:if test="@morerows">
      <xsl:attribute name="rowspan"> <!-- set the number of rows to span -->
        <xsl:value-of select="@morerows+1"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@spanname">
      <xsl:attribute name="colspan"> <!-- get the number of columns to span from the corresponding spanspec -->
        <xsl:call-template name="find-spanspec-colspan"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if
        test="@namest and @nameend"> <!-- get the number of columns to span from the specified named column values -->
      <xsl:attribute name="colspan">
        <xsl:call-template name="find-colspan"/>
      </xsl:attribute>
    </xsl:if>

    <!-- Add any flags from tgroup, thead or tbody, and row -->
    <xsl:apply-templates select="../../../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="../../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:choose>
      <!-- When entry is empty, output a blank -->
      <xsl:when test="not(*|text()|processing-instruction())">
        <xsl:text>&#160;</xsl:text>  <!-- nbsp -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="../../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="../../../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <!-- Find the starting column of an entry in a row. -->
  <xsl:template name="find-entry-start-position">
    <xsl:choose>

      <!-- if the column number is specified, use it -->
      <xsl:when test="@colnum">
        <xsl:value-of select="@colnum"/>
      </xsl:when>

      <!-- If there is a defined column name, check the colspans to determine position -->
      <xsl:when test="@colname">
        <!-- count the number of colspans before the one this entry references, plus one -->
        <xsl:value-of
            select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = current()/@colname]/preceding-sibling::*[contains(@class, ' topic/colspec ')])+1)"/>
      </xsl:when>

      <!-- If the starting column is defined, check colspans to determine position -->
      <xsl:when test="@namest">
        <xsl:value-of
            select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = current()/@namest]/preceding-sibling::*[contains(@class, ' topic/colspec ')])+1)"/>
      </xsl:when>

      <!-- Need a test for spanspec -->
      <xsl:when test="@spanname">
        <xsl:variable name="startspan">  <!-- starting column for this span -->
          <xsl:value-of
              select="../../../*[contains(@class, ' topic/spanspec ')][@spanname = current()/@spanname]/@namest"/>
        </xsl:variable>
        <xsl:value-of
            select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = $startspan]/preceding-sibling::*[contains(@class, ' topic/colspec ')])+1)"/>
      </xsl:when>

      <!-- Otherwise, just use the count of cells in this row -->
      <xsl:otherwise>
        <xsl:variable name="prev-sib" select="count(preceding-sibling::*[contains(@class, ' topic/entry ')])"/>
        <xsl:value-of select="$prev-sib+1"/>
      </xsl:otherwise>

    </xsl:choose>
  </xsl:template>

  <!-- Find the end column of a cell. If the cell does not span any columns,
       the end position is the same as the start position. -->
  <xsl:template name="find-entry-end-position">
    <xsl:param name="startposition" select="0"/>
    <xsl:choose>
      <xsl:when test="@nameend">
        <xsl:value-of
            select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = current()/@nameend]/preceding-sibling::*[contains(@class, ' topic/colspec ')])+1)"/>
      </xsl:when>
      <xsl:when test="@spanname">
        <xsl:variable name="endspan">  <!-- starting column for this span -->
          <xsl:value-of
              select="../../../*[contains(@class, ' topic/spanspec ')][@spanname = current()/@spanname]/@nameend"/>
        </xsl:variable>
        <xsl:value-of
            select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = $endspan]/preceding-sibling::*[contains(@class, ' topic/colspec ')])+1)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$startposition"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Check <thead> entries, and return IDs for those which match the desired column -->
  <xsl:template
      match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]"
      mode="findmatch">
    <xsl:param name="startmatch" select="1"/>  <!-- start column of the tbody cell -->
    <xsl:param name="endmatch" select="1"/>    <!-- end column of the tbody cell -->
    <xsl:variable name="entrystartpos">         <!-- start column of this thead cell -->
      <xsl:call-template name="find-entry-start-position"/>
    </xsl:variable>
    <xsl:variable name="entryendpos">           <!-- end column of this thead cell -->
      <xsl:call-template name="find-entry-end-position">
        <xsl:with-param name="startposition" select="$entrystartpos"/>
      </xsl:call-template>
    </xsl:variable>
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
        <xsl:text></xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Check the first column for entries that line up with the test row.
       Any entries that line up need to have the header saved. This template is first
       called with the first entry of the first row in <tbody>. It is called from here
       on the next cell in column one.            -->
  <xsl:template match="*[contains(@class, ' topic/entry ')]" mode="check-first-column">
    <xsl:param name="startMatchRow" select="1"/>   <!-- First row of the tbody cell we are matching -->
    <xsl:param name="endMatchRow" select="1"/>     <!-- Last row of the tbody cell we are matching -->
    <xsl:param name="startCurrentRow" select="1"/> <!-- First row of the column-1 cell we are testing -->
    <xsl:variable name="endCurrentRow">            <!-- Last row of the column-1 cell we are testing -->
      <xsl:choose>
        <!-- If @morerows, the cell ends at startCurrentRow + @morerows. Otherise, start=end. -->
        <xsl:when test="@morerows">
          <xsl:value-of select="number($startCurrentRow)+number(@morerows)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$startCurrentRow"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <!-- When the current column-1 cell ends before the tbody cell we are matching -->
      <xsl:when test="number($endCurrentRow) &lt; number($startMatchRow)">
        <!-- Call this template again with the next entry in column one -->
        <xsl:if test="parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]">
          <xsl:apply-templates
              select="parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]/*[contains(@class, ' topic/entry ')][1]"
              mode="check-first-column">
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
        <xsl:value-of select="generate-id(.)"/>
        <xsl:text></xsl:text>
        <!-- If we are not at the end of the tbody cell, and more rows exist, continue testing column 1 -->
        <xsl:if test="number($endCurrentRow) &lt; number($endMatchRow) and
                      parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]">
          <xsl:apply-templates
              select="parent::*/parent::*/*[contains(@class, ' topic/row ')][number($endCurrentRow)+1]/*[contains(@class, ' topic/entry ')][1]"
              mode="check-first-column">
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
    <!-- Determine the start column for the current cell -->
    <xsl:variable name="entrystartpos">
      <xsl:call-template name="find-entry-start-position"/>
    </xsl:variable>
    <!-- Determine the end column for the current cell -->
    <xsl:variable name="entryendpos">
      <xsl:call-template name="find-entry-end-position">
        <xsl:with-param name="startposition" select="$entrystartpos"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- Find the IDs of headers that are aligned above this cell. This is done by applying
         templates on all headers, using mode=findmatch; matching IDs are returned. -->
    <xsl:variable name="hdrattr">
      <xsl:apply-templates select="../../../*[contains(@class, ' topic/thead ')]/
                                            *[contains(@class, ' topic/row ')]/
                                            *[contains(@class, ' topic/entry ')]" mode="findmatch">
        <xsl:with-param name="startmatch" select="$entrystartpos"/>
        <xsl:with-param name="endmatch" select="$entryendpos"/>
      </xsl:apply-templates>
    </xsl:variable>
    <!-- Find the IDs of headers in the first column, which are aligned with this cell -->
    <xsl:variable name="rowheader">
      <!-- If this entry is not in the first column or in thead, and @rowheader=firstcol on table -->
      <xsl:if test="not(number($entrystartpos) = 1) and
                    not(parent::*/parent::*[contains(@class, ' topic/thead ')]) and
                    ../../../../@rowheader = 'firstcol'">
        <!-- Find the start row for this entry -->
        <xsl:variable name="startrow"
                      select="number(count(parent::*/preceding-sibling::*[contains(@class, ' topic/row ')])+1)"/>
        <!-- Find the end row for this entry -->
        <xsl:variable name="endrow">
          <xsl:if test="@morerows">
            <xsl:value-of select="number($startrow) + number(@morerows)"/>
          </xsl:if>
          <xsl:if test="not(@morerows)">
            <xsl:value-of select="$startrow"/>
          </xsl:if>
        </xsl:variable>
        <!-- Scan first-column entries for ones that align with this cell, starting with
             the first entry in the first row -->
        <xsl:apply-templates
            select="../../*[contains(@class, ' topic/row ')][1]/*[contains(@class, ' topic/entry ')][1]"
            mode="check-first-column">
          <xsl:with-param name="startMatchRow" select="$startrow"/>
          <xsl:with-param name="endMatchRow" select="$endrow"/>
        </xsl:apply-templates>
      </xsl:if>
    </xsl:variable>
    <xsl:if test="string-length($rowheader) > 0 or string-length($hdrattr) > 0">
      <xsl:attribute name="headers" select="concat($rowheader, $hdrattr)"/>
    </xsl:if>
  </xsl:template>

  <!-- Find the number of column spans between name-start and name-end attrs -->
  <xsl:template name="find-colspan">
    <xsl:variable name="startpos">
      <xsl:call-template name="find-entry-start-position"/>
    </xsl:variable>
    <xsl:variable name="endpos">
      <xsl:call-template name="find-entry-end-position"/>
    </xsl:variable>
    <xsl:value-of select="$endpos - $startpos + 1"/>
  </xsl:template>

  <xsl:template name="find-spanspec-colspan">
    <xsl:variable name="spanname" select="@spanname"/>
    <xsl:variable name="startcolname"
                  select="../../../*[contains(@class, ' topic/spanspec ')][@spanname = $spanname][1]/@namest"/>
    <xsl:variable name="endcolname"
                  select="../../../*[contains(@class, ' topic/spanspec ')][@spanname = $spanname][1]/@nameend"/>
    <xsl:variable name="startpos"
                  select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = $startcolname]/preceding-sibling::*)+1)"/>
    <xsl:variable name="endpos"
                  select="number(count(../../../*[contains(@class, ' topic/colspec ')][@colname = $endcolname]/preceding-sibling::*)+1)"/>
    <xsl:value-of select="$endpos - $startpos + 1"/>
  </xsl:template>

  <!-- end of table section -->

  <!-- ===================================================================== -->

  <!-- =========== SimpleTable - SEMANTIC TABLE =========== -->

  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="generate-table-summary-attribute">
    <!-- Override this to use a local convention for setting table's @summary attribute,
         until OASIS provides a standard mechanism for setting. -->
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" name="topic.simpletable">
    <!-- Find the total number of relative units for the table. If @relcolwidth="1* 2* 2*",
         the variable is set to 5. -->
    <xsl:variable name="totalwidth">
      <xsl:if test="@relcolwidth">
        <xsl:call-template name="find-total-table-width"/>
      </xsl:if>
    </xsl:variable>
    <!-- Find how much of the table each relative unit represents. If @relcolwidth is 1* 2* 2*,
         there are 5 units. So, each unit takes up 100/5, or 20% of the table. Default to 0,
         which the entries will ignore. -->
    <xsl:variable name="width-multiplier">
      <xsl:choose>
        <xsl:when test="@relcolwidth">
          <xsl:value-of select="100 div $totalwidth"/>
        </xsl:when>
        <xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="count" as="xs:integer">
      <xsl:variable name="count-per-row" as="xs:integer*">
        <xsl:for-each select="*[contains(@class, ' topic/sthead ')] | *[contains(@class, ' topic/strow ')]">
          <xsl:sequence select="count(*[contains(@class, ' topic/stentry ')])"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:sequence select="max($count-per-row)"/>
    </xsl:variable>
    <xsl:variable name="relcolwidth" as="xs:double*">
      <xsl:for-each select="tokenize(normalize-space(translate(@relcolwidth, '*', '')), '\s+')">
        <xsl:sequence select="xs:double(.)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:call-template name="spec-title"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <table>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:for-each select="1 to $count">
        <col>
          <xsl:if test=". le count($relcolwidth)">
            <xsl:attribute name="width" select="$relcolwidth[current()]"/>
          </xsl:if>
        </col>
      </xsl:for-each>
      <thead>
        <xsl:apply-templates select="." mode="dita2html:simpletable-heading">
          <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
        </xsl:apply-templates>
      </thead>
      <tbody>
        <xsl:apply-templates
            select="*[contains(@class, ' topic/strow ')]|processing-instruction()">     <!-- width-multiplier will be used in the first row to set widths. -->
          <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
        </xsl:apply-templates>
      </tbody>
    </table>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>

  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/strow ')]" name="topic.strow">
    <xsl:param name="width-multiplier"/>
    <tr>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:choose>
        <!-- If there are any rows or headers before this, the width values have already been set. -->
        <xsl:when test="preceding-sibling::*[contains(@class, ' topic/strow ')]">
          <xsl:apply-templates/>
        </xsl:when>
        <!-- Otherwise, this is the first row. Pass the percentage to all entries in this row. -->
        <xsl:otherwise>
          <xsl:apply-templates>
            <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
    </tr>
  </xsl:template>

  <!-- Specialized simpletables may match this rule to create default column 
       headings. By default, process the sthead if available. -->
  <xsl:template match="*" mode="dita2html:simpletable-heading">
    <xsl:param name="width-multiplier"/>
    <xsl:apply-templates select="*[contains(@class, ' topic/sthead ')]">
      <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/sthead ')]" name="topic.sthead">
    <xsl:param name="width-multiplier"/>
    <tr>
      <xsl:call-template name="commonattributes"/>
      <!-- There is only one sthead, so use the entries in the header to set relative widths. -->
      <xsl:apply-templates>
        <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
      </xsl:apply-templates>
    </tr>
  </xsl:template>

  <!-- Output the ID for a simpletable entry, when it is specified. If no ID is specified,
       and this is a header row, generate an ID. The entry is considered a header entry
       when the it is inside <sthead>, or when it is in the column specified in the keycol
       attribute on <simpletable>
       NOTE: It references simpletable with parent::*/parent::* in order to avoid problems
       with nested simpletables. -->
  <xsl:template name="output-stentry-id">
    <!-- Find the position in this row -->
    <xsl:variable name="thiscolnum">
      <xsl:number level="single" count="*[contains(@class, ' topic/stentry ')]"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="@id">    <!-- If ID is specified, always use it -->
        <xsl:attribute name="id" select="dita-ot:generate-html-id(.)"/>
      </xsl:when>
      <!-- If no ID is specified, and this is a header cell, generate an ID -->
      <xsl:when test="parent::*[contains(@class, ' topic/sthead ')] or
                      (parent::*/parent::*/@keycol and number(parent::*/parent::*/@keycol) = number($thiscolnum))">
        <xsl:attribute name="id" select="generate-id(.)"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/stentry ')]" name="topic.stentry">
    <xsl:param name="width-multiplier" select="0"/>
    <xsl:choose>
      <xsl:when test="parent::*[contains(@class, ' topic/sthead ')]">
        <xsl:call-template name="topic.sthead_stentry">
          <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="topic.strow_stentry">
          <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- sthead/stentry - bottom align the header text -->
  <xsl:template name="topic.sthead_stentry">
    <xsl:param name="width-multiplier" select="0"/>
    <tablecell>
      <xsl:call-template name="th-align"/>
      <xsl:call-template name="output-stentry-id"/>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:choose>
        <!-- If there is text, or a PI, or non-flagging element child -->
        <xsl:when
            test="*[not(contains(@class, ' ditaot-d/startprop ') or contains(@class, ' dita-ot/endprop '))] | text() | processing-instruction()">
          <xsl:apply-templates/>
        </xsl:when>
        <xsl:otherwise>
          <!-- Add flags, then either @specentry or NBSP -->
          <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
          <xsl:choose>
            <xsl:when test="@specentry">
              <xsl:value-of select="@specentry"/>
            </xsl:when>
            <xsl:otherwise>&#160;</xsl:otherwise>
          </xsl:choose>
          <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </tablecell>
  </xsl:template>

  <!-- For simple table headers: <TH> Set align="right" when in a BIDI area -->
  <xsl:template name="th-align">
    <xsl:variable name="biditest" as="xs:boolean">
      <xsl:call-template name="bidi-area"/>
    </xsl:variable>
    <xsl:attribute name="align" select="if ($biditest) then 'right' else 'left'"/>
  </xsl:template>

  <!-- stentry  -->
  <!-- for specentry - if no text in cell, output specentry attr; otherwise output text -->
  <!-- Bold the @keycol column. Get the column's number. When (Nth stentry = the @keycol value) then bold the stentry -->
  <xsl:template name="topic.strow_stentry">
    <xsl:param name="width-multiplier" select="0"/>
    <tablecell>
      <xsl:call-template name="output-stentry-id"/>
      <!--xsl:call-template name="set.stentry.headers"/-->
      <xsl:call-template name="commonattributes"/>
      <xsl:variable name="localkeycol" as="xs:integer">
        <xsl:choose>
          <xsl:when test="ancestor::*[contains(@class, ' topic/simpletable ')]/@keycol">
            <xsl:value-of select="ancestor::*[contains(@class, ' topic/simpletable ')]/@keycol"/>
          </xsl:when>
          <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- Determine which column this entry is in. -->
      <xsl:variable name="thiscolnum" select="count(preceding-sibling::*[contains(@class, ' topic/stentry ')]) + 1"/>
      <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:choose>
        <xsl:when test="$thiscolnum = $localkeycol">
          <strong>
            <xsl:call-template name="stentry-templates"/>
          </strong>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stentry-templates"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </tablecell>
  </xsl:template>
  <xsl:template name="stentry-templates">
    <xsl:choose>
      <xsl:when test="not(*|text()|processing-instruction()) and @specentry">
        <xsl:value-of select="@specentry"/>
      </xsl:when>
      <xsl:when test="not(*|text()|processing-instruction())">
        <xsl:text>&#160;</xsl:text>  <!-- nbsp -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Use @relcolwidth to find the total width of the table. That is, if the attribute is set
       to 1* 2* 2* 1*, then the table is 6 units wide. -->
  <xsl:template name="find-total-table-width">
    <!-- Start with relcolwidth, and each recursive call will remove the first value -->
    <xsl:param name="relcolwidth" select="@relcolwidth"/>
    <!-- Determine the first value, which is the value before the first asterisk -->
    <xsl:variable name="firstval">
      <xsl:if test="contains($relcolwidth, '*')">
        <xsl:value-of select="substring-before($relcolwidth, '*')"/>
      </xsl:if>
    </xsl:variable>
    <!-- Begin processing if we were able to find a first value -->
    <xsl:if test="string-length($firstval) > 0">
      <!-- Chop off the first value, and set morevals to the remainder -->
      <xsl:variable name="morevals" select="substring-after($relcolwidth, ' ')"/>
      <xsl:choose>
        <!-- If there are additional values, call this template on the remainder.
             Add the result of that call to the first value. -->
        <xsl:when test="string-length($morevals) > 0">
          <xsl:variable name="nextval">   <!-- The total of the remaining values -->
            <xsl:call-template name="find-total-table-width">
              <xsl:with-param name="relcolwidth" select="$morevals"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:value-of select="number($firstval) + number($nextval)"/>
        </xsl:when>
        <!-- If there are no more values, return the first (and only) value -->
        <xsl:otherwise>
          <xsl:value-of select="$firstval"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <!-- Find the width of the current cell. Multiplier is how much each unit of width is multiplied to total 100.
       Entry-num is the current entry. Current-col is what column we are at when scanning @relcolwidth.
       Relcolvalues is the unscanned part of @relcolwidth. -->
  <xsl:template name="get-current-entry-percentage">
    <!-- Each relative unit is worth this many percentage points -->
    <xsl:param name="multiplier" select="1" as="xs:double"/>
    <!-- The entry number of the cell we are evaluating now -->
    <xsl:param name="entry-num" as="xs:double"/>
    <!-- Position within the recursive call to evaluate @relcolwidth -->
    <xsl:param name="current-col" select="1" as="xs:double"/>
    <!-- relcolvalues begins with @relcolwidth. Each call to the template removes the first value. -->
    <xsl:param name="relcolvalues" select="parent::*/parent::*/@relcolwidth"/>

    <xsl:choose>
      <!-- If the recursion has moved up to the proper cell, multiply $multiplier by the number of
           relative units for this column. -->
      <xsl:when test="$entry-num = $current-col">
        <xsl:variable name="relcol" select="number(substring-before($relcolvalues, '*'))"/>
        <xsl:value-of select="$relcol * $multiplier"/>
      </xsl:when>
      <!-- Otherwise, call this template again, removing the first value form @relcolwidth. Also add one
           to $current-col. -->
      <xsl:otherwise>
        <xsl:call-template name="get-current-entry-percentage">
          <xsl:with-param name="multiplier" select="$multiplier"/>
          <xsl:with-param name="entry-num" select="$entry-num"/>
          <xsl:with-param name="current-col" select="$current-col + 1"/>
          <xsl:with-param name="relcolvalues" select="substring-after($relcolvalues, ' ')"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
