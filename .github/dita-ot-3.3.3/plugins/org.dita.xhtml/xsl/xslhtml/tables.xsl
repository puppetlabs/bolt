<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:table="http://dita-ot.sourceforge.net/ns/201007/dita-ot/table"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                exclude-result-prefixes="xs dita-ot dita2html ditamsg table">
  
  <xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/tablefunctions.xsl"/>

<!-- =========== CALS (OASIS) TABLE =========== -->
  
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
  
  <xsl:template match="*[contains(@class,' topic/table ')]
    [empty(*[contains(@class,' topic/tgroup ')]/*[contains(@class,' topic/tbody ')]/*[contains(@class,' topic/row ')])]" priority="10"/>
  <xsl:template match="*[contains(@class,' topic/tgroup ')]
    [empty(*[contains(@class,' topic/tbody ')]/*[contains(@class,' topic/row ')])]" priority="10"/>

<xsl:template match="*[contains(@class, ' topic/table ')]" name="topic.table">
  <xsl:value-of select="$newline"/>
  <!-- special case for IE & NS for frame & no rules - needs to be a double table -->
  <xsl:variable name="colsep">
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/tgroup ')]/@colsep">
        <xsl:value-of select="*[contains(@class, ' topic/tgroup ')]/@colsep"/>
      </xsl:when>
      <xsl:when test="@colsep">
        <xsl:value-of select="@colsep"/>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="rowsep">
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/tgroup ')]/@rowsep">
        <xsl:value-of select="*[contains(@class, ' topic/tgroup ')]/@rowsep"/>
      </xsl:when>
      <xsl:when test="@rowsep">
        <xsl:value-of select="@rowsep"/>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="@frame = 'all' and $colsep = '0' and $rowsep = '0'">
      <table cellpadding="4" cellspacing="0" border="1" class="tableborder">
        <tr>
          <td>
            <xsl:value-of select="$newline"/>
            <xsl:call-template name="dotable"/>
          </td>
        </tr>
      </table>
    </xsl:when>
    <xsl:when test="@frame = 'top' and $colsep = '0' and $rowsep = '0'">
      <hr />
      <xsl:value-of select="$newline"/>
      <xsl:call-template name="dotable"/>
    </xsl:when>
    <xsl:when test="@frame = 'bot' and $colsep = '0' and $rowsep = '0'">
      <xsl:call-template name="dotable"/>
      <hr />
      <xsl:value-of select="$newline"/>
    </xsl:when>
    <xsl:when test="@frame = 'topbot' and $colsep = '0' and $rowsep = '0'">
      <hr />
      <xsl:value-of select="$newline"/>
      <xsl:call-template name="dotable"/>
      <hr />
      <xsl:value-of select="$newline"/>
    </xsl:when>
    <xsl:when test="not(@frame) and $colsep = '0' and $rowsep = '0'">
      <table cellpadding="4" cellspacing="0" border="1" class="tableborder">
        <tr>
          <td>
            <xsl:value-of select="$newline"/>
            <xsl:call-template name="dotable"/>
          </td>
        </tr>
      </table>
    </xsl:when>
    <xsl:otherwise>
      <div class="tablenoborder">
        <xsl:call-template name="dotable"/>
      </div>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template name="dotable">
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:call-template name="setaname"/>
  <table cellpadding="4" cellspacing="0" summary="">
    <xsl:variable name="colsep">
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/tgroup ')]/@colsep"><xsl:value-of select="*[contains(@class, ' topic/tgroup ')]/@colsep"/></xsl:when>
        <xsl:when test="@colsep"><xsl:value-of select="@colsep"/></xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="rowsep">
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/tgroup ')]/@rowsep"><xsl:value-of select="*[contains(@class, ' topic/tgroup ')]/@rowsep"/></xsl:when>
        <xsl:when test="@rowsep"><xsl:value-of select="@rowsep"/></xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:call-template name="setid"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="." mode="generate-table-summary-attribute"/>
    <xsl:call-template name="setscale"/>
    <!-- When a table's width is set to page or column, force it's width to 100%. If it's in a list, use 90%.
         Otherwise, the table flows to the content -->
    <xsl:choose>
      <xsl:when test="(@expanse = 'page' or @pgwide = '1')and (ancestor::*[contains(@class, ' topic/li ')] or ancestor::*[contains(@class, ' topic/dd ')] )">
        <xsl:attribute name="width">90%</xsl:attribute>
      </xsl:when>
      <xsl:when test="(@expanse = 'column' or @pgwide = '0') and (ancestor::*[contains(@class, ' topic/li ')] or ancestor::*[contains(@class, ' topic/dd ')] )">
        <xsl:attribute name="width">90%</xsl:attribute>
      </xsl:when>
      <xsl:when test="(@expanse = 'page' or @pgwide = '1')">
        <xsl:attribute name="width">100%</xsl:attribute>
      </xsl:when>
      <xsl:when test="(@expanse = 'column' or @pgwide = '0')">
        <xsl:attribute name="width">100%</xsl:attribute>
      </xsl:when>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="@frame = 'all' and $colsep = '0' and $rowsep = '0'">
        <xsl:attribute name="border">0</xsl:attribute>
      </xsl:when>
      <xsl:when test="not(@frame) and $colsep = '0' and $rowsep = '0'">
        <xsl:attribute name="border">0</xsl:attribute>
      </xsl:when>
      <xsl:when test="@frame = 'sides'">
        <xsl:attribute name="frame">vsides</xsl:attribute>
        <xsl:attribute name="border">1</xsl:attribute>
      </xsl:when>
      <xsl:when test="@frame = 'top'">
        <xsl:attribute name="frame">above</xsl:attribute>
        <xsl:attribute name="border">1</xsl:attribute>
      </xsl:when>
      <xsl:when test="@frame = 'bottom'">
        <xsl:attribute name="frame">below</xsl:attribute>
        <xsl:attribute name="border">1</xsl:attribute>
      </xsl:when>
      <xsl:when test="@frame = 'topbot'">
        <xsl:attribute name="frame">hsides</xsl:attribute>
        <xsl:attribute name="border">1</xsl:attribute>
      </xsl:when>
      <xsl:when test="@frame = 'none'">
        <xsl:attribute name="frame">void</xsl:attribute>
        <xsl:attribute name="border">1</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="frame">border</xsl:attribute>
        <xsl:attribute name="border">1</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="@frame = 'all' and $colsep = '0' and $rowsep = '0'">
        <xsl:attribute name="border">0</xsl:attribute>
      </xsl:when>
      <xsl:when test="not(@frame) and $colsep = '0' and $rowsep = '0'">
        <xsl:attribute name="border">0</xsl:attribute>
      </xsl:when>
      <xsl:when test="$colsep = '0' and $rowsep = '0'">
        <xsl:attribute name="rules">none</xsl:attribute>
        <xsl:attribute name="border">0</xsl:attribute>
      </xsl:when>
      <xsl:when test="$colsep = '0'">
        <xsl:attribute name="rules">rows</xsl:attribute>
      </xsl:when>
      <xsl:when test="$rowsep = '0'">
        <xsl:attribute name="rules">cols</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="rules">all</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="place-tbl-lbl"/>
    <!-- title and desc are processed elsewhere -->
    <xsl:apply-templates select="*[contains(@class, ' topic/tgroup ')]"/>
    </table><xsl:value-of select="$newline"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
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

<xsl:template match="*[contains(@class, ' topic/thead ')]" name="topic.thead">
  <thead>
    <!-- Get style from parent tgroup, then override with thead if specified locally -->
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:call-template name="commonattributes"/>
    
    
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:choose>
          <xsl:when test="@align">
            <xsl:text>text-align:</xsl:text>
            <xsl:value-of select="@align"/>
            <xsl:text>;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="th-align"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@valign">
          <xsl:text>vertical-align:</xsl:text>
          <xsl:value-of select="@valign"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:if test="@char">
      <xsl:attribute name="char" select="@char"/>
    </xsl:if>
    <xsl:if test="@charoff">
      <xsl:attribute name="charoff" select="@charoff"/>
    </xsl:if>
    <xsl:apply-templates/>
  </thead><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/tbody ')]" name="topic.tbody">
  <tbody>
    <!-- Get style from parent tgroup, then override with thead if specified locally -->
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:if test="@align">
          <xsl:text>text-align:</xsl:text>
          <xsl:value-of select="@align"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
        <xsl:if test="@valign">
          <xsl:text>vertical-align:</xsl:text>
          <xsl:value-of select="@valign"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:if test="@char">
      <xsl:attribute name="char" select="@char"/>
    </xsl:if>
    <xsl:if test="@charoff">
      <xsl:attribute name="charoff" select="@charoff"/>
    </xsl:if>
    <xsl:apply-templates/>
  </tbody><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/row ')]" name="topic.row">
  <tr>
    <xsl:call-template name="setid"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:if test="@align">
          <xsl:text>text-align:</xsl:text>
          <xsl:value-of select="@align"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
        <xsl:if test="@valign">
          <xsl:text>vertical-align:</xsl:text>
          <xsl:value-of select="@valign"/>
          <xsl:text>;</xsl:text>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:if test="@char">
      <xsl:attribute name="char" select="@char"/>
    </xsl:if>
    <xsl:if test="@charoff">
      <xsl:attribute name="charoff" select="@charoff"/>
    </xsl:if>
    <xsl:apply-templates/>
  </tr><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/entry ')]" name="topic.entry">
  <xsl:choose>
      <xsl:when test="parent::*/parent::*[contains(@class, ' topic/thead ')]">
          <xsl:call-template name="topic.thead_entry"/>
      </xsl:when>
      <xsl:otherwise>
          <xsl:call-template name="topic.tbody_entry"/>
      </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- do header entries -->
<xsl:template name="topic.thead_entry">
 <th>
  <xsl:call-template name="doentry"/>
 </th><xsl:value-of select="$newline"/>
</xsl:template>

<!-- do body entries -->
<xsl:template name="topic.tbody_entry">
  <xsl:choose>
    <xsl:when test="../../../../@rowheader = 'firstcol' and @dita-ot:x = 1">
      <th><xsl:call-template name="doentry"/></th>
    </xsl:when>
    <xsl:otherwise>
      <td><xsl:call-template name="doentry"/></td>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template name="doentry">
  <xsl:variable name="this-colname" select="@colname"/>
  <!-- Rowsep/colsep: Skip if the last row or column. Only check the entry and colsep;
    if set higher, will already apply to the whole table. -->
  <xsl:variable name="row" select=".." as="element()"/>
  <xsl:variable name="body" select="../.." as="element()"/>
  <xsl:variable name="group" select="../../.." as="element()"/>
  <xsl:variable name="colspec" select="../../../*[contains(@class, ' topic/colspec ')][@colname and @colname = $this-colname]" as="element()?"/>
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
    <xsl:attribute name="headers">
      <xsl:for-each select="distinct-values($all-row-headers)">
        <xsl:value-of select="concat(.,' ')"/>
      </xsl:for-each>
      <xsl:for-each select="distinct-values($all-thead-headers)">
        <xsl:value-of select="concat(.,' ')"/>
      </xsl:for-each>
    </xsl:attribute>
  </xsl:if>
</xsl:template>

<!-- =========== SimpleTable - SEMANTIC TABLE =========== -->
  
  <xsl:template match="*[contains(@class,' topic/simpletable ')]
    [empty(*[contains(@class,' topic/strow ')]/*[contains(@class,' topic/stentry ')])]" priority="10"/>
  <xsl:template match="*[contains(@class,' topic/strow ') or contains(@class,' topic/sthead ')][empty(*[contains(@class,' topic/stentry ')])]" priority="10"/>
  

<xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="generate-table-summary-attribute">
  <!-- Override this to use a local convention for setting table's @summary attribute,
       until OASIS provides a standard mechanism for setting. -->
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/simpletable ')]" name="topic.simpletable">
  <xsl:call-template name="spec-title"/>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:call-template name="setaname"/>
  <table cellpadding="4" cellspacing="0" summary="">
   <xsl:call-template name="setid"/>
    <xsl:choose>
     <xsl:when test="@frame = 'none'">
      <xsl:attribute name="border">0</xsl:attribute>
      <xsl:attribute name="class">simpletablenoborder</xsl:attribute>
     </xsl:when>
     <xsl:otherwise>
      <xsl:attribute name="border">1</xsl:attribute>
      <xsl:attribute name="class">simpletableborder</xsl:attribute>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="." mode="generate-table-summary-attribute"/>
    <xsl:call-template name="setscale"/>
    <xsl:call-template name="dita2html:simpletable-cols"/>
    <xsl:apply-templates select="." mode="dita2html:simpletable-heading"/>
    <tbody>    
      <xsl:apply-templates select="*[contains(@class, ' topic/strow ')]|processing-instruction()"/>
    </tbody>
  </table>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:value-of select="$newline"/>
</xsl:template>
  
  <xsl:template name="dita2html:simpletable-cols">
    <xsl:variable name="col-count" as="xs:integer">
      <xsl:apply-templates select="." mode="dita2html:get-max-entry-count"/>
    </xsl:variable>
    <xsl:variable name="col-widths" as="xs:double*">
      <xsl:variable name="widths" select="tokenize(normalize-space(translate(@relcolwidth, '*', '')), '\s+')" as="xs:string*"/>
      <xsl:for-each select="$widths">
        <xsl:choose>
          <xsl:when test=". castable as xs:double">
            <xsl:sequence select="xs:double(.)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="xs:double(1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
      <xsl:for-each select="1 to ($col-count - count($widths))">
        <xsl:sequence select="xs:double(1)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="col-widths-sum" select="sum($col-widths)"/>
    <xsl:for-each select="$col-widths">      
      <col style="width:{(. div $col-widths-sum) * 100}%"/>
    </xsl:for-each>    
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="dita2html:get-max-entry-count" as="xs:integer">
    <xsl:variable name="counts" as="xs:integer*">
      <xsl:for-each select="*[contains(@class, ' topic/sthead ')] |
                            *[contains(@class, ' topic/strow ')]">
        <xsl:sequence select="count(*[contains(@class, ' topic/stentry ')])"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="max($counts)"/>
  </xsl:template>

<xsl:template match="*[contains(@class, ' topic/strow ')]" name="topic.strow">
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
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </tr><xsl:value-of select="$newline"/>
</xsl:template>

<!-- Specialized simpletables may match this rule to create default column 
     headings. By default, process the sthead if available. -->
<xsl:template match="*" mode="dita2html:simpletable-heading">
  <thead>
    <xsl:apply-templates select="*[contains(@class, ' topic/sthead ')]"/>
  </thead>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/sthead ')]" name="topic.sthead">
  <tr>
    <xsl:call-template name="commonattributes"/>
    <!-- There is only one sthead, so use the entries in the header to set relative widths. -->
    <xsl:apply-templates/>
  </tr><xsl:value-of select="$newline"/>
</xsl:template>

<!-- Output the ID for a simpletable entry, when it is specified. If no ID is specified,
     and this is a header row, generate an ID. The entry is considered a header entry
     when the it is inside <sthead>, or when it is in the column specified in the keycol
     attribute on <simpletable>
     NOTE: It references simpletable with parent::*/parent::* in order to avoid problems
     with nested simpletables. -->
<xsl:template name="output-stentry-id">
  <!-- Find the position in this row -->
  <xsl:variable name="thiscolnum"><xsl:number level="single" count="*[contains(@class, ' topic/stentry ')]"/></xsl:variable>
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

<!-- Output the headers attribute for screen readers. If specified, it should match both
     of the following:
     * the <stentry> with the same position in the sthead
     * the <stentry> that is in the key column (specified in @keycol on simpletable)
     Note: This function is not called within sthead, so sthead never gets headers.
     NOTE: I reference simpletable with parent::*/parent::* in order to avoid problems
     with nested simpletables. -->
<xsl:template name="set.stentry.headers">
  <xsl:variable name="keycol" select="parent::*/parent::*/@keycol"/>
  <xsl:if test="$keycol | parent::*/parent::*/*[contains(@class, ' topic/sthead ')]">
      <xsl:variable name="thiscolnum"><xsl:number level="single" count="*[contains(@class, ' topic/stentry ')]"/></xsl:variable>

      <!-- If there is a keycol, and this is not the key column, get the ID for the keycol -->
      <xsl:variable name="keycolhead">
          <xsl:if test="$keycol and $thiscolnum != number($keycol)">
            <xsl:variable name="col" select="../*[number($keycol)]"/>
              <xsl:choose>
                  <xsl:when test="$col/@id">
                      <xsl:value-of select="$col/@id"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="generate-id($col)"/>
                  </xsl:otherwise>
              </xsl:choose>
          </xsl:if>
      </xsl:variable>

      <!-- If there is a header, get the ID from the head cell in this column.
           Go up to simpletable, into the row, to the entry at column $thiscolnum -->
      <xsl:variable name="header">
          <xsl:if test="parent::*/parent::*/*[contains(@class, ' topic/sthead ')]/*[contains(@class, ' topic/stentry ')][number($thiscolnum)]">
            <xsl:value-of select="dita-ot:generate-html-id(parent::*/parent::*/*[contains(@class, ' topic/sthead ')]/*[contains(@class, ' topic/stentry ')][number($thiscolnum)])"/>
          </xsl:if>
      </xsl:variable>

      <!-- If there is a keycol header or an sthead header, create the attribute -->
      <xsl:if test="string-length($header) > 0 or string-length($keycolhead) > 0">
          <xsl:attribute name="headers">
              <xsl:value-of select="$header"/>
              <xsl:if test="string-length($header) > 0 and string-length($keycolhead) > 0"><xsl:text> </xsl:text></xsl:if>
              <xsl:value-of select="$keycolhead"/>
          </xsl:attribute>
      </xsl:if>
  </xsl:if>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/stentry ')]" name="topic.stentry">
    <xsl:choose>
        <xsl:when test="parent::*[contains(@class, ' topic/sthead ')]">
            <xsl:call-template name="topic.sthead_stentry"/>
        </xsl:when>
        <xsl:otherwise>
            <xsl:call-template name="topic.strow_stentry"/>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<!-- sthead/stentry - bottom align the header text -->
<xsl:template name="topic.sthead_stentry">
  <th>
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:text>vertical-align:bottom;</xsl:text>
        <xsl:call-template name="th-align"/>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="output-stentry-id"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:choose>
      <!-- If there is text, or a PI, or non-flagging element child -->
      <xsl:when test="*[not(contains(@class, ' ditaot-d/startprop ') or contains(@class, ' dita-ot/endprop '))] | text() | processing-instruction()">
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Add flags, then either @specentry or NBSP -->
        <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
        <xsl:choose>
          <xsl:when test="@specentry"><xsl:value-of select="@specentry"/></xsl:when>
          <xsl:otherwise>&#160;</xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
      </xsl:otherwise>
     </xsl:choose>
     <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </th><xsl:value-of select="$newline"/>
</xsl:template>

<!-- For simple table headers: <TH> Set align="right" when in a BIDI area -->
<xsl:template name="th-align">
 <xsl:variable name="biditest" as="xs:boolean">
  <xsl:call-template name="bidi-area"/>
 </xsl:variable>
  <xsl:text>text-align:</xsl:text>
  <xsl:value-of select="if ($biditest) then 'right' else 'left'"/>
  <xsl:text>;</xsl:text>
</xsl:template>

<!-- stentry  -->
<!-- for specentry - if no text in cell, output specentry attr; otherwise output text -->
<!-- Bold the @keycol column. Get the column's number. When (Nth stentry = the @keycol value) then bold the stentry -->
<xsl:template name="topic.strow_stentry">
  <xsl:variable name="localkeycol">
    <xsl:choose>
      <xsl:when test="ancestor::*[contains(@class, ' topic/simpletable ')]/@keycol">
        <xsl:value-of select="ancestor::*[contains(@class, ' topic/simpletable ')]/@keycol"/>
      </xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <!-- Determine which column this entry is in. -->
  <xsl:variable name="thiscolnum" select="number(count(preceding-sibling::*[contains(@class, ' topic/stentry ')])+1)"/>
  <xsl:variable name="element-name">
    <xsl:choose>
      <xsl:when test="$thiscolnum = $localkeycol">th</xsl:when>
      <xsl:otherwise>td</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:element name="{$element-name}">
    <xsl:call-template name="style">
      <xsl:with-param name="contents">
        <xsl:text>vertical-align:top;</xsl:text>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="output-stentry-id"/>
    <xsl:call-template name="set.stentry.headers"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="stentry-templates"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:element>
  <xsl:value-of select="$newline"/>
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

<!-- ========== "FORMAT" MACROS  - Table title, figure title, InfoNavGraphic ========== -->
<!--
| These macros support globally-defined formatting constants for
| document content.  Some elements have attributes that permit local
| control of formatting; such logic is part of the pertinent template rule.
+-->

<xsl:template name="place-tbl-width">
  <xsl:variable name="twidth-fixed">100%</xsl:variable>
  <xsl:if test="$twidth-fixed != ''">
    <xsl:attribute name="width" select="$twidth-fixed"/>
  </xsl:if>
</xsl:template>

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

<!-- These 2 rules are not actually used, but could be picked up by an override -->
<xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]" name="topic.table_title">
  <span><xsl:apply-templates/></span>
</xsl:template>
<!-- These rules are not actually used, but could be picked up by an override -->
<xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/desc ')]" name="topic.table_desc">
  <span><xsl:apply-templates/></span>
</xsl:template>

</xsl:stylesheet>
