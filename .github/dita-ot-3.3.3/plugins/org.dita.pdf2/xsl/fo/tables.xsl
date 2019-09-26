<!--
This file is part of the DITA Open Toolkit project.

Copyright 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:dita2xslfo="http://dita-ot.sourceforge.net/ns/200910/dita2xslfo"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  exclude-result-prefixes="opentopic-func xs dita2xslfo dita-ot"
  version="2.0">

    <xsl:variable name="tableAttrs" select="'../../cfg/fo/attrs/tables-attr.xsl'"/>

    <xsl:param name="tableSpecNonProportional" select="'false'"/>

    <!-- XML Exchange Table Model Document Type Definition default is all -->
    <xsl:variable name="table.frame-default" select="'all'"/>
    <!-- XML Exchange Table Model Document Type Definition default is 1 -->
    <xsl:variable name="table.rowsep-default" select="'0'"/>
    <!-- XML Exchange Table Model Document Type Definition default is 1 -->
    <xsl:variable name="table.colsep-default" select="'0'"/>

    <!--Definition list-->
    <xsl:template match="*[contains(@class,' topic/dl ')][empty(*[contains(@class,' topic/dlentry ')])]" priority="10"/>
    
    <xsl:template match="*[contains(@class, ' topic/dl ')]">
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
        <fo:table xsl:use-attribute-sets="dl">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="*[contains(@class, ' topic/dlhead ')]"/>
            <fo:table-body xsl:use-attribute-sets="dl__body">
                <xsl:choose>
                    <xsl:when test="contains(@otherprops,'sortable')">
                        <xsl:apply-templates select="*[contains(@class, ' topic/dlentry ')]">
                            <xsl:sort select="opentopic-func:getSortString(normalize-space( opentopic-func:fetchValueableText(*[contains(@class, ' topic/dt ')]) ))" lang="{$locale}"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="*[contains(@class, ' topic/dlentry ')]"/>
                    </xsl:otherwise>
                </xsl:choose>
            </fo:table-body>
        </fo:table>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
    </xsl:template>
    
    <xsl:template match="*[contains(@class,' topic/dlhead ')]
        [empty(*[contains(@class,' topic/dthd ')] | *[contains(@class,' topic/ddhd ')])]" priority="10"/>

    <xsl:template match="*[contains(@class, ' topic/dl ')]/*[contains(@class, ' topic/dlhead ')]">
        <fo:table-header xsl:use-attribute-sets="dl.dlhead">
            <xsl:call-template name="commonattributes"/>
            <fo:table-row xsl:use-attribute-sets="dl.dlhead__row">
                <xsl:apply-templates/>
            </fo:table-row>
        </fo:table-header>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/dlhead ')]/*[contains(@class, ' topic/dthd ')]">
        <fo:table-cell xsl:use-attribute-sets="dlhead.dthd__cell">
            <xsl:call-template name="commonattributes"/>
            <fo:block xsl:use-attribute-sets="dlhead.dthd__content">
                <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
                <xsl:apply-templates/>
            </fo:block>
        </fo:table-cell>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/dlhead ')]/*[contains(@class, ' topic/ddhd ')]">
        <fo:table-cell xsl:use-attribute-sets="dlhead.ddhd__cell">
            <xsl:call-template name="commonattributes"/>
            <fo:block xsl:use-attribute-sets="dlhead.ddhd__content">
                <xsl:apply-templates/>
                <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
            </fo:block>
        </fo:table-cell>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/dlentry ')]">
        <fo:table-row xsl:use-attribute-sets="dlentry">
            <xsl:call-template name="commonattributes"/>
            <fo:table-cell xsl:use-attribute-sets="dlentry.dt">
                <xsl:apply-templates select="*[contains(@class, ' topic/dt ')]"/>
                <xsl:if test="empty(*[contains(@class, ' topic/dt ')])"><fo:block/></xsl:if>
            </fo:table-cell>
            <fo:table-cell xsl:use-attribute-sets="dlentry.dd">
                <xsl:apply-templates select="*[contains(@class, ' topic/dd ')]"/>
                <xsl:if test="empty(*[contains(@class, ' topic/dd ')])"><fo:block/></xsl:if>
            </fo:table-cell>
        </fo:table-row>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/dt ')]">
        <fo:block xsl:use-attribute-sets="dlentry.dt__content">
            <xsl:if test="not(preceding-sibling::*[contains(@class,' topic/dt ')])">
              <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
            </xsl:if>
            <xsl:apply-templates select="." mode="inlineTextOptionalKeyref"/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/dd ')]">
        <fo:block xsl:use-attribute-sets="dlentry.dd__content">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
            <xsl:if test="not(following-sibling::*[contains(@class,' topic/dd ')])">
              <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
            </xsl:if>
        </fo:block>
    </xsl:template>

    <!--  Map processing  -->
    <xsl:template match="*[contains(@class, ' map/map ')]/*[contains(@class, ' map/reltable ')]">
        <fo:table-and-caption>
            <fo:table-caption>
                <fo:block xsl:use-attribute-sets="reltable__title">
                    <xsl:value-of select="@title"/>
                </fo:block>
            </fo:table-caption>
            <fo:table xsl:use-attribute-sets="reltable">
                <xsl:call-template name="topicrefAttsNoToc"/>
                <xsl:call-template name="selectAtts"/>
                <xsl:call-template name="globalAtts"/>

                <xsl:apply-templates select="relheader"/>

                <fo:table-body>
                    <xsl:apply-templates select="relrow"/>
                </fo:table-body>

            </fo:table>
        </fo:table-and-caption>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' map/relheader ')]">
        <fo:table-header xsl:use-attribute-sets="relheader">
            <xsl:call-template name="globalAtts"/>
            <xsl:apply-templates/>
        </fo:table-header>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' map/relcolspec ')]">
        <fo:table-cell xsl:use-attribute-sets="relcolspec">
            <xsl:apply-templates/>
        </fo:table-cell>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' map/relrow ')]">
        <fo:table-row xsl:use-attribute-sets="relrow">
            <xsl:call-template name="globalAtts"/>
            <xsl:apply-templates/>
        </fo:table-row>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' map/relcell ')]">
        <fo:table-cell xsl:use-attribute-sets="relcell">
            <xsl:call-template name="globalAtts"/>
            <xsl:call-template name="topicrefAtts"/>

            <xsl:apply-templates/>

        </fo:table-cell>
    </xsl:template>

    <!-- DITA-OT flagging preprocess may add flag info directly into simpletable; account for that and
         skip to next row. Currently known to match ditaval-startprop when flagging used on simpletable
         as well as suitesol:changebar-start when revision bar used on sthead or stentry. -->
    <xsl:template match="*" mode="count-max-simpletable-cells" as="xs:integer">
      <xsl:param name="maxcount" select="0" as="xs:integer"/>
      <xsl:apply-templates select="following-sibling::*[1]" mode="count-max-simpletable-cells">
        <xsl:with-param name="maxcount" select="$maxcount"/>
      </xsl:apply-templates>
    </xsl:template>
    <!-- Count the max number of cells in any row of a simpletable -->
    <xsl:template match="*[contains(@class, ' topic/sthead ')] | *[contains(@class, ' topic/strow ')]" mode="count-max-simpletable-cells" as="xs:integer">
      <xsl:param name="maxcount" select="0" as="xs:integer"/>
      <xsl:variable name="newmaxcount" as="xs:integer">
        <xsl:variable name="row-cell-count" select="count(*[contains(@class, ' topic/stentry ')])" as="xs:integer"/>
        <xsl:sequence select="max(($row-cell-count, $maxcount))"/>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="not(following-sibling::*[contains(@class, ' topic/strow ')])">
          <xsl:sequence select="$newmaxcount"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="following-sibling::*[contains(@class, ' topic/strow ')][1]" mode="count-max-simpletable-cells">
            <xsl:with-param name="maxcount" select="$newmaxcount"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <!-- If there are more cells in any row than there are relcolwidth values,
         add 1* for each missing cell, otherwise the FO processor may crash. -->
    <xsl:template match="*" mode="fix-relcolwidth">
      <xsl:param name="number-cells" as="xs:integer"/>
      <xsl:variable name="relcolwidth-tokens" select="tokenize(normalize-space(@relcolwidth), '\s+')" as="xs:string*"/>
      <xsl:variable name="number-relwidths" select="count($relcolwidth-tokens)" as="xs:integer"/>
      <xsl:variable name="result" as="xs:string*">
        <xsl:sequence select="$relcolwidth-tokens"/>
        <xsl:for-each select="1 to ($number-cells - $number-relwidths)">1*</xsl:for-each>
      </xsl:variable>
      <xsl:value-of select="$result" separator=" "/>
    </xsl:template>

  <xsl:function name="dita-ot:get-length">
    <xsl:param name="width" as="xs:string"/>
    <xsl:value-of select="normalize-space(translate($width,
                                                    '+-0123456789.abcdefghijklmnopqrstuvwxyz%',
                                                    '+-0123456789.'))"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-entry-end-position" as="xs:integer">
    <xsl:param name="thisentry" as="element()"/>
    <xsl:choose>
      <xsl:when test="$thisentry/@dita-ot:x and $thisentry/@dita-ot:morecols">
        <xsl:sequence select="xs:integer($thisentry/@dita-ot:x) + xs:integer($thisentry/@dita-ot:morecols)"/>
      </xsl:when>
      <xsl:when test="$thisentry/@dita-ot:x">
        <xsl:sequence select="xs:integer($thisentry/@dita-ot:x)"/>
      </xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-unit">
    <xsl:param name="width" as="xs:string"/>
    <xsl:value-of select="normalize-space(translate($width,
                                                    'abcdefghijklmnopqrstuvwxyz%+-0123456789.',
                                                    'abcdefghijklmnopqrstuvwxyz%'))"/>
  </xsl:function>

    <xsl:template name="univAttrs">
        <xsl:apply-templates select="@platform | @product | @audience | @otherprops | @importance | @rev | @status"/>
    </xsl:template>

    <xsl:function name="opentopic-func:getSortString" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="contains($text, '[') and contains($text, ']')">
                <xsl:value-of select="substring-before(substring-after($text, '['),']')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="opentopic-func:fetchValueableText" as="xs:string">
        <xsl:param name="node" as="element()*"/>

        <xsl:value-of>
            <xsl:apply-templates select="$node" mode="insert-text"/>
        </xsl:value-of>
    </xsl:function>

    <xsl:template match="*" mode="insert-text">
        <xsl:apply-templates mode="insert-text"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/indexterm ')]" mode="insert-text"/>

    <xsl:template match="text()[contains(., '[') and contains(., ']')][ancestor::*[contains(@class, ' topic/dl ')][contains(@otherprops,'sortable')]]" priority="10">
        <xsl:value-of select="substring-before(.,'[')"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/table ')]">
      <!-- FIXME, empty value -->
        <xsl:variable name="scale" as="xs:string?">
            <xsl:call-template name="getTableScale"/>
        </xsl:variable>

        <fo:block-container xsl:use-attribute-sets="table__container">
            <fo:block xsl:use-attribute-sets="table">
                <xsl:call-template name="commonattributes"/>
                <xsl:if test="not(@id)">
                  <xsl:attribute name="id">
                    <xsl:call-template name="get-id"/>
                  </xsl:attribute>
                </xsl:if>
                <xsl:if test="exists($scale)">
                    <xsl:attribute name="font-size" select="concat($scale, '%')"/>
                </xsl:if>
                <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
                <xsl:apply-templates/>
                <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
            </fo:block>
        </fo:block-container>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]">
        <fo:block xsl:use-attribute-sets="table.title">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="customTitleAnchor"/>
            <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="'Table.title'"/>
                <xsl:with-param name="params">
                    <number>
                      <xsl:apply-templates select="." mode="table.title-number"/>
                    </number>
                    <title>
                        <xsl:apply-templates/>
                    </title>
                </xsl:with-param>
            </xsl:call-template>
        </fo:block>
    </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ')]" mode="table.title-number">
    <xsl:value-of select="count(key('enumerableByClass', 'topic/table')[. &lt;&lt; current()][dita-ot:notExcludedByDraftElement(.)])"/>
  </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/tgroup ')]" name="tgroup">
        <xsl:if test="not(@cols)">
          <xsl:call-template name="output-message">
            <xsl:with-param name="id" select="'PDFX006E'"/>
          </xsl:call-template>
        </xsl:if>

        <xsl:variable name="scale" as="xs:string?">
            <xsl:call-template name="getTableScale"/>
        </xsl:variable>

        <xsl:variable name="table" as="element()">
            <fo:table xsl:use-attribute-sets="table.tgroup">
                <xsl:call-template name="commonattributes"/>

                <xsl:call-template name="displayAtts">
                    <xsl:with-param name="element" select=".."/>
                </xsl:call-template>

                <xsl:if test="(parent::*/@pgwide) = '1'">
                    <xsl:attribute name="start-indent">0</xsl:attribute>
                    <xsl:attribute name="end-indent">0</xsl:attribute>
                    <xsl:attribute name="width">auto</xsl:attribute>
                </xsl:if>

                <xsl:apply-templates/>
            </fo:table>
        </xsl:variable>

        <xsl:choose>
            <xsl:when test="exists($scale)">
                <xsl:apply-templates select="$table" mode="setTableEntriesScale"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="$table"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
  
    <xsl:template match="*[contains(@class, ' topic/tgroup ')][empty(*[contains(@class, ' topic/tbody ')]//*[contains(@class, ' topic/row ')])]" priority="10"/>

    <xsl:template match="*[contains(@class, ' topic/colspec ')]">
        <fo:table-column>
          <xsl:attribute name="column-number" select="@colnum"/>
          <xsl:if test="normalize-space(@colwidth)">
            <xsl:attribute name="column-width">
              <xsl:choose>
                <xsl:when test="not(normalize-space(@colwidth))">
                  <xsl:call-template name="calculateColumnWidth.Proportional">
                    <xsl:with-param name="colwidth" select="'1*'"/>
                  </xsl:call-template>
                </xsl:when>
                <xsl:when test="contains(@colwidth, '*')">
                  <xsl:call-template name="calculateColumnWidth.Proportional">
                    <xsl:with-param name="colwidth" select="@colwidth"/>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="calculateColumnWidth.nonProportional">
                    <xsl:with-param name="colwidth" select="@colwidth"/>
                  </xsl:call-template>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
          </xsl:if>
          <xsl:call-template name="applyAlignAttrs"/>
        </fo:table-column>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/thead ')]">
        <fo:table-header xsl:use-attribute-sets="tgroup.thead">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:table-header>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/tbody ')]">
        <fo:table-body xsl:use-attribute-sets="tgroup.tbody">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:table-body>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]">
        <fo:table-row xsl:use-attribute-sets="thead.row">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:table-row>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/tbody ')]/*[contains(@class, ' topic/row ')]">
        <fo:table-row xsl:use-attribute-sets="tbody.row">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:table-row>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/entry ')]" mode="validate-entry-position">
        <xsl:if test="dita-ot:get-entry-end-position(.) gt number(ancestor::*[contains(@class,' topic/tgroup ')][1]/@cols)">
            <xsl:call-template name="output-message">
                <xsl:with-param name="id" select="'PDFX012E'"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]">
        <xsl:apply-templates select="." mode="validate-entry-position"/>
        <fo:table-cell xsl:use-attribute-sets="thead.row.entry">
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="applySpansAttrs"/>
            <xsl:call-template name="applyAlignAttrs"/>
            <xsl:call-template name="generateTableEntryBorder"/>
            <xsl:choose>
                <xsl:when test="@rotate eq '1'">
                    <xsl:apply-templates select="." mode="rotateTableEntryContent"/>
                </xsl:when>
                <xsl:otherwise>
                    <fo:block xsl:use-attribute-sets="thead.row.entry__content">
                        <xsl:call-template name="processEntryContent"/>
                    </fo:block>
                </xsl:otherwise>
                </xsl:choose>
        </fo:table-cell>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="rotateTableEntryContent">
        <fo:block-container reference-orientation="90">
            <fo:block xsl:use-attribute-sets="thead.row.entry__content">
                <xsl:call-template name="processEntryContent"/>
            </fo:block>
        </fo:block-container>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/tbody ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]">
        <xsl:apply-templates select="." mode="validate-entry-position"/>
        <xsl:choose>
            <xsl:when test="ancestor::*[contains(@class, ' topic/table ')][1]/@rowheader = 'firstcol'
                and @dita-ot:x = '1'">
                <fo:table-cell xsl:use-attribute-sets="tbody.row.entry__firstcol">
                    <xsl:apply-templates select="." mode="processTableEntry"/>
                </fo:table-cell>
            </xsl:when>
            <xsl:otherwise>
                <fo:table-cell xsl:use-attribute-sets="tbody.row.entry">
                    <xsl:apply-templates select="." mode="processTableEntry"/>
                </fo:table-cell>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="processTableEntry">
        <xsl:call-template name="commonattributes"/>
        <xsl:call-template name="applySpansAttrs"/>
        <xsl:call-template name="applyAlignAttrs"/>
        <xsl:call-template name="generateTableEntryBorder"/>
        <xsl:choose>
            <xsl:when test="@rotate eq '1'">
                <xsl:apply-templates select="." mode="rotateTableEntryContent"/>
            </xsl:when>
            <xsl:otherwise>
                <fo:block xsl:use-attribute-sets="tbody.row.entry__content">
                    <xsl:call-template name="processEntryContent"/>
                </fo:block>
            </xsl:otherwise>
            </xsl:choose>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' topic/tbody ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="rotateTableEntryContent">
        <fo:block-container reference-orientation="90">
            <fo:block xsl:use-attribute-sets="tbody.row.entry__content">
                <xsl:call-template name="processEntryContent"/>
            </fo:block>
        </fo:block-container>
    </xsl:template>

    <xsl:template name="processEntryContent">
      <xsl:variable name="entryNumber" select="@dita-ot:x" as="xs:integer?"/>
        <xsl:variable name="colspec" select="ancestor::*[contains(@class, ' topic/tgroup ')][1]/*[contains(@class, ' topic/colspec ')][position() = $entryNumber]" as="element()?"/>
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
        <xsl:variable name="charoff" as="xs:integer">
            <xsl:choose>
                <xsl:when test="@charoff">
                  <xsl:sequence select="xs:integer(@charoff)"/>
                </xsl:when>
                <xsl:when test="$colspec/@charoff">
                  <xsl:sequence select="xs:integer($colspec/@charoff)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="xs:integer(50)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:apply-templates select="." mode="ancestor-start-flag"/>
        <xsl:choose>
            <xsl:when test="exists($char) and string-length($char) ne 0">
                <xsl:call-template name="processCharAlignment">
                  <xsl:with-param name="char" select="$char"/>
                  <xsl:with-param name="charoff" select="$charoff"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="." mode="ancestor-end-flag"/>
    </xsl:template>

  <xsl:template name="processCharAlignment">
    <xsl:param name="char" as="xs:string"/>
    <xsl:param name="charoff" as="xs:integer"/>
        <xsl:choose>
            <xsl:when test="not(descendant::* | descendant::processing-instruction() | descendant::comment())">
                <xsl:variable name="text-before" select="substring-before(text(), $char)"/>
                <xsl:variable name="text-after" select="substring-after(text(), $text-before)"/>
                <fo:list-block start-indent="0pt"
                    provisional-label-separation="0pt"
                    provisional-distance-between-starts="{concat($charoff, '%')}">
                    <fo:list-item>
                        <fo:list-item-label end-indent="label-end()">
                            <fo:block text-align="end">
                                <xsl:copy-of select="$text-before"/>
                            </fo:block>
                        </fo:list-item-label>
                        <fo:list-item-body start-indent="body-start()">
                            <fo:block text-align="start">
                                <xsl:copy-of select="$text-after"/>
                            </fo:block>
                        </fo:list-item-body>
                    </fo:list-item>
                </fo:list-block>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="calculateColumnWidth.Proportional">
        <xsl:param name="colwidth" as="xs:string"/>

        <xsl:text>proportional-column-width(</xsl:text>
        <xsl:choose>
            <xsl:when test="substring-before($colwidth, '*') != ''">
                <xsl:value-of select="normalize-space(substring-before($colwidth, '*'))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>1.00</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:text>)</xsl:text>
    </xsl:template>

    <xsl:template name="calculateColumnWidth.nonProportional">
        <xsl:param name="colwidth" as="xs:string"/>

        <xsl:variable name="width-units" as="xs:string">
            <xsl:choose>
              <!-- XXX: This should never occur -->
                <xsl:when test="contains($colwidth, '*')">
                    <xsl:value-of select="normalize-space(substring-after($colwidth, '*'))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="normalize-space($colwidth)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="width" select="dita-ot:get-length($width-units)"/>

        <xsl:variable name="units" select="dita-ot:get-unit($width-units)"/>

        <xsl:value-of select="$width"/>

        <xsl:choose>
            <xsl:when test="$units = 'pi'">pc</xsl:when>
            <xsl:when test="$units = '' and $width != ''">pt</xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$units"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="applySpansAttrs">
        <xsl:if test="exists(@morerows) and xs:integer(@morerows) gt 0">
            <xsl:attribute name="number-rows-spanned">
              <xsl:value-of select="xs:integer(@morerows) + 1"/>
            </xsl:attribute>
        </xsl:if>
      <xsl:if test="exists(@dita-ot:morecols) and xs:integer(@dita-ot:morecols) gt 0">
        <xsl:attribute name="number-columns-spanned">
        <xsl:value-of select="xs:integer(@dita-ot:morecols) + 1"/>
        </xsl:attribute>
      </xsl:if>
    </xsl:template>

    <xsl:template name="applyAlignAttrs">
        <xsl:variable name="align" as="xs:string?">
            <xsl:choose>
                <xsl:when test="@align">
                    <xsl:value-of select="@align"/>
                </xsl:when>
                <xsl:when test="ancestor::*[contains(@class, ' topic/tbody ')][1][@align]">
                    <xsl:value-of select="ancestor::*[contains(@class, ' topic/tbody ')][1]/@align"/>
                </xsl:when>
                <xsl:when test="ancestor::*[contains(@class, ' topic/thead ')][1][@align]">
                    <xsl:value-of select="ancestor::*[contains(@class, ' topic/thead ')][1]/@align"/>
                </xsl:when>
                <xsl:when test="ancestor::*[contains(@class, ' topic/tgroup ')][1][@align]">
                    <xsl:value-of select="ancestor::*[contains(@class, ' topic/tgroup ')][1]/@align"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="valign" as="xs:string?">
            <xsl:choose>
                <xsl:when test="@valign">
                    <xsl:value-of select="@valign"/>
                </xsl:when>
                <xsl:when test="parent::*[contains(@class, ' topic/row ')][@valign]">
                    <xsl:value-of select="parent::*[contains(@class, ' topic/row ')]/@valign"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>

        <xsl:choose>
            <xsl:when test="not(normalize-space($align) = '')">
                <xsl:attribute name="text-align">
                    <xsl:value-of select="$align"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:when test="(normalize-space($align) = '') and contains(@class, ' topic/colspec ')"/>
            <xsl:otherwise>
                <xsl:attribute name="text-align">from-table-column()</xsl:attribute>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:choose>
            <xsl:when test="$valign='top'">
                <xsl:attribute name="display-align">
                    <xsl:value-of select="'before'"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:when test="$valign='middle'">
                <xsl:attribute name="display-align">
                    <xsl:value-of select="'center'"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:when test="$valign='bottom'">
                <xsl:attribute name="display-align">
                    <xsl:value-of select="'after'"/>
                </xsl:attribute>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="generateTableEntryBorder">
        <xsl:variable name="colsep" as="xs:string">
            <xsl:call-template name="getTableColsep"/>
        </xsl:variable>
        <xsl:variable name="rowsep" as="xs:string">
            <xsl:call-template name="getTableRowsep"/>
        </xsl:variable>
        <xsl:variable name="frame" as="xs:string" select="(ancestor::*[contains(@class, ' topic/table ')][1]/@frame, $table.frame-default)[1]"/>
        <xsl:variable name="needTopBorderOnBreak" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="$frame = ('all', 'topbot', 'top')">
                    <xsl:choose>
                        <xsl:when test="../parent::node()[contains(@class, ' topic/thead ')]">
                            <xsl:sequence select="true()"/>
                        </xsl:when>
                        <xsl:when test="(../parent::node()[contains(@class, ' topic/tbody ')]) and not(../preceding-sibling::*[contains(@class, ' topic/row ')])">
                            <xsl:sequence select="true()"/>
                        </xsl:when>
                        <xsl:when test="../parent::node()[contains(@class, ' topic/tbody ')]">
                            <xsl:variable name="entryNum" select="count(preceding-sibling::*[contains(@class, ' topic/entry ')]) + 1"/>
                            <xsl:variable name="prevEntryRowsep" as="xs:string?">
                                <xsl:for-each select="../preceding-sibling::*[contains(@class, ' topic/row ')][1]/*[contains(@class, ' topic/entry ')][$entryNum]">
                                    <xsl:call-template name="getTableRowsep"/>
                                </xsl:for-each>
                            </xsl:variable>
                            <xsl:choose>
                                <xsl:when test="$prevEntryRowsep != '0'">
                                    <xsl:sequence select="true()"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:sequence select="false()"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="false()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="false()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="number($rowsep) = 1 and (../parent::node()[contains(@class, ' topic/thead ')])">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'thead__tableframe__bottom'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:if test="number($rowsep) = 1 and ((../following-sibling::*[contains(@class, ' topic/row ')]) or (../parent::node()[contains(@class, ' topic/tbody ')] and ancestor::*[contains(@class, ' topic/tgroup ')][1]/*[contains(@class, ' topic/tfoot ')]))">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__bottom'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:if test="$needTopBorderOnBreak">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__top'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:if test="number($colsep) = 1 and following-sibling::*[contains(@class, ' topic/entry ')]">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__right'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:if test="number($colsep) = 1 and not(following-sibling::*[contains(@class, ' topic/entry ')]) and ((count(preceding-sibling::*) + 1) &lt; ancestor::*[contains(@class, ' topic/tgroup ')][1]/@cols)">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__right'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <!-- DITA spec prose defines as either 0 or 1, but DTD as NMTOKENS. However, OASIS Table Exchange model uses 0 or anything else. -->
    <xsl:template name="getTableColsep" as="xs:string">
        <xsl:variable name="colname" select="@colname"/>
        <xsl:choose>
            <xsl:when test="@colsep">
                <xsl:value-of select="@colsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/tgroup ')][1]/*[contains(@class, ' topic/colspec ')][@colname = $colname]/@colsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/tgroup ')][1]/*[contains(@class, ' topic/colspec ')][@colname = $colname]/@colsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/tgroup ')][1]/@colsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/tgroup ')][1]/@colsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/table ')][1]/@colsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/table ')][1]/@colsep"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$table.colsep-default"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="getTableRowsep" as="xs:string">
        <xsl:variable name="colname" select="@colname"/>
        <xsl:choose>
            <xsl:when test="@rowsep">
                <xsl:value-of select="@rowsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/row ')][1]/@rowsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/row ')][1]/@rowsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/tgroup ')][1]/*[contains(@class, ' topic/colspec ')][@colname = $colname]/@rowsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/tgroup ')][1]/*[contains(@class, ' topic/colspec ')][@colname = $colname]/@rowsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/tgroup ')][1]/@rowsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/tgroup ')][1]/@rowsep"/>
            </xsl:when>
            <xsl:when test="ancestor::*[contains(@class, ' topic/table ')][1]/@rowsep">
                <xsl:value-of select="ancestor::*[contains(@class, ' topic/table ')][1]/@rowsep"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$table.rowsep-default"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="displayAtts">
        <xsl:param name="element" as="element()"/>
        <xsl:variable name="frame" as="xs:string" select="($element/@frame, $table.frame-default)[1]"/>

        <xsl:if test="$element/@expanse">
          <xsl:for-each select="$element">
            <xsl:call-template name="setExpanse"/>
          </xsl:for-each>
        </xsl:if>

        <xsl:choose>
            <xsl:when test="$frame = 'all'">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'table__tableframe__all'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$frame = 'topbot'">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'table__tableframe__topbot'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$frame = 'top'">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'table__tableframe__top'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$frame = 'bottom'">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'table__tableframe__bottom'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$frame = 'sides'">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'table__tableframe__sides'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="getTableScale" as="xs:string?">
        <xsl:sequence select="ancestor-or-self::*[contains(@class, ' topic/table ')][1]/@scale"/>
    </xsl:template>

    <xsl:template match="@*" mode="setTableEntriesScale">
        <xsl:choose>
            <xsl:when test="name() = 'font-size'">
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="node() | text()" mode="setTableEntriesScale">
        <xsl:copy>
            <xsl:apply-templates select="node() | @* | text()" mode="setTableEntriesScale"/>
        </xsl:copy>
    </xsl:template>

    <!--  Simpletable processing  -->
    <xsl:template match="*[contains(@class, ' topic/simpletable ')]">
        <xsl:variable name="number-cells" as="xs:integer">
            <!-- Contains the number of cells in the widest row -->
            <xsl:apply-templates select="*[1]" mode="count-max-simpletable-cells"/>
        </xsl:variable>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
        <fo:table xsl:use-attribute-sets="simpletable">
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="globalAtts"/>
            <xsl:call-template name="displayAtts">
                <xsl:with-param name="element" select="."/>
            </xsl:call-template>

            <xsl:if test="@relcolwidth">
                <xsl:variable name="fix-relcolwidth" as="xs:string">
                    <xsl:apply-templates select="." mode="fix-relcolwidth">
                        <xsl:with-param name="number-cells" select="$number-cells"/>
                    </xsl:apply-templates>
                </xsl:variable>
                <xsl:call-template name="createSimpleTableColumns">
                    <xsl:with-param name="theColumnWidthes" select="$fix-relcolwidth"/>
                </xsl:call-template>
            </xsl:if>

            <!-- Toss processing to another template to process the simpletable
                 heading, and/or create a default table heading row. -->
            <xsl:apply-templates select="." mode="dita2xslfo:simpletable-heading">
                <xsl:with-param name="number-cells" select="$number-cells"/>
            </xsl:apply-templates>

            <fo:table-body xsl:use-attribute-sets="simpletable__body">
                <xsl:choose>
                  <xsl:when test="empty(*[contains(@class, ' topic/strow ')])">
                    <fo:table-row>
                        <fo:table-cell>
                            <fo:block/>
                        </fo:table-cell>
                    </fo:table-row>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:apply-templates select="*[contains(@class, ' topic/strow ')]">
                        <xsl:with-param name="number-cells" select="$number-cells"/>
                    </xsl:apply-templates>
                  </xsl:otherwise>
                </xsl:choose>
            </fo:table-body>

        </fo:table>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
    </xsl:template>
  
    <xsl:template match="*[contains(@class,' topic/simpletable ')]
        [empty(*[contains(@class,' topic/strow ')]/*[contains(@class,' topic/stentry ')])]" priority="10"/>
    <xsl:template match="*[contains(@class,' topic/strow ') or contains(@class,' topic/sthead ')][empty(*[contains(@class,' topic/stentry ')])]" priority="10"/>

    <xsl:template name="createSimpleTableColumns">
        <xsl:param name="theColumnWidthes" as="xs:string"/>
        <xsl:for-each select="tokenize(normalize-space($theColumnWidthes), '\s+')">
          <fo:table-column>
            <xsl:attribute name="column-width">
              <xsl:call-template name="calculateColumnWidth.Proportional">
                <xsl:with-param name="colwidth" select="."/>
              </xsl:call-template>
            </xsl:attribute>
          </fo:table-column>
        </xsl:for-each>
    </xsl:template>

    <!-- Fill in empty cells when one is missing from strow or sthead.
         Context for this call is strow or sthead. -->
    <xsl:template match="*" mode="fillInMissingSimpletableCells">
        <xsl:param name="fill-in-count" select="0" as="xs:integer"/>
        <xsl:variable name="current" select="."/>
        <xsl:for-each select="1 to $fill-in-count">
          <xsl:for-each select="$current">
            <fo:table-cell xsl:use-attribute-sets="strow.stentry">
                <xsl:call-template name="commonattributes"/>
                <xsl:variable name="frame" as="xs:string" select="(../@frame, $table.frame-default)[1]"/>
                <xsl:if test="following-sibling::*[contains(@class, ' topic/strow ')]">
                    <xsl:apply-templates select="." mode="simpletableHorizontalBorders">
                        <xsl:with-param name="frame" select="$frame" as="xs:string"/>
                    </xsl:apply-templates>
                </xsl:if>
                <xsl:apply-templates select="." mode="simpletableTopBorder">
                    <xsl:with-param name="frame" select="$frame" as="xs:string"/>
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="simpletableSideBorders">
                    <xsl:with-param name="frame" select="$frame" as="xs:string"/>
                </xsl:apply-templates>
                <fo:block>
                    <fo:inline>&#160;</fo:inline>
                </fo:block>
            </fo:table-cell>
          </xsl:for-each>
        </xsl:for-each>
    </xsl:template>

    <!-- Specialized simpletable elements may override this rule to add
         default headings for the table. By default, the existing sthead
         element is used when specified. -->
    <xsl:template match="*[contains(@class, ' topic/simpletable ')]" mode="dita2xslfo:simpletable-heading">
        <xsl:param name="number-cells" as="xs:integer">
            <xsl:apply-templates select="*[1]" mode="count-max-simpletable-cells"/>
        </xsl:param>
        <xsl:apply-templates select="*[contains(@class, ' topic/sthead ')]">
            <xsl:with-param name="number-cells" select="$number-cells"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/sthead ')]">
      <xsl:param name="number-cells" as="xs:integer">
            <xsl:apply-templates select="../*[1]" mode="count-max-simpletable-cells"/>
        </xsl:param>
        <fo:table-header xsl:use-attribute-sets="sthead">
            <xsl:call-template name="commonattributes"/>
            <fo:table-row xsl:use-attribute-sets="sthead__row">
                <xsl:apply-templates select="*[contains(@class, ' topic/stentry ')]"/>
                <xsl:variable name="row-cell-count" select="count(*[contains(@class, ' topic/stentry ')])" as="xs:integer"/>
                <xsl:if test="$row-cell-count &lt; $number-cells">
                    <xsl:apply-templates select="." mode="fillInMissingSimpletableCells">
                        <xsl:with-param name="fill-in-count" select="$number-cells - $row-cell-count"/>
                    </xsl:apply-templates>
                </xsl:if>
            </fo:table-row>
        </fo:table-header>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/strow ')]">
        <xsl:param name="number-cells" as="xs:integer">
            <xsl:apply-templates select="../*[1]" mode="count-max-simpletable-cells"/>
        </xsl:param>
        <fo:table-row xsl:use-attribute-sets="strow">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="*[contains(@class, ' topic/stentry ')]"/>
            <xsl:variable name="row-cell-count" select="count(*[contains(@class, ' topic/stentry ')])" as="xs:integer"/>
            <xsl:if test="$row-cell-count &lt; $number-cells">
                <xsl:apply-templates select="." mode="fillInMissingSimpletableCells">
                    <xsl:with-param name="fill-in-count" select="$number-cells - $row-cell-count"/>
                </xsl:apply-templates>
            </xsl:if>
        </fo:table-row>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/sthead ')]/*[contains(@class, ' topic/stentry ')]">
        <fo:table-cell xsl:use-attribute-sets="sthead.stentry">
            <xsl:call-template name="commonattributes"/>
            <xsl:variable name="entryCol" select="count(preceding-sibling::*[contains(@class, ' topic/stentry ')]) + 1"/>
            <xsl:variable name="frame" as="xs:string" select="(ancestor::*[contains(@class, ' topic/simpletable ')][1]/@frame, $table.frame-default)[1]"/>

            <xsl:apply-templates select="." mode="simpletableHorizontalBorders">
                <xsl:with-param name="frame" select="$frame" as="xs:string"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="simpletableTopBorder">
                <xsl:with-param name="frame" select="$frame" as="xs:string"/>
            </xsl:apply-templates>
            <xsl:if test="following-sibling::*[contains(@class, ' topic/stentry ')]">
                <xsl:apply-templates select="." mode="simpletableVerticalBorders">
                    <xsl:with-param name="frame" select="$frame" as="xs:string"/>
                </xsl:apply-templates>
            </xsl:if>

            <xsl:choose>
                <xsl:when test="number(ancestor::*[contains(@class, ' topic/simpletable ')][1]/@keycol) = $entryCol">
                    <fo:block xsl:use-attribute-sets="sthead.stentry__keycol-content">
                        <xsl:apply-templates select="." mode="ancestor-start-flag"/>
                        <xsl:apply-templates/>
                        <xsl:apply-templates select="." mode="ancestor-end-flag"/>
                    </fo:block>
                </xsl:when>
                <xsl:otherwise>
                    <fo:block xsl:use-attribute-sets="sthead.stentry__content">
                        <xsl:apply-templates select="." mode="ancestor-start-flag"/>
                        <xsl:apply-templates/>
                        <xsl:apply-templates select="." mode="ancestor-end-flag"/>
                    </fo:block>
                </xsl:otherwise>
            </xsl:choose>
        </fo:table-cell>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/strow ')]/*[contains(@class, ' topic/stentry ')]">
        <fo:table-cell xsl:use-attribute-sets="strow.stentry">
            <xsl:call-template name="commonattributes"/>
            <xsl:variable name="entryCol" select="count(preceding-sibling::*[contains(@class, ' topic/stentry ')]) + 1"/>
            <xsl:variable name="frame" as="xs:string" select="(ancestor::*[contains(@class, ' topic/simpletable ')][1]/@frame, $table.frame-default)[1]"/>

            <xsl:if test="../following-sibling::*[contains(@class, ' topic/strow ')]">
                <xsl:apply-templates select="." mode="simpletableHorizontalBorders">
                    <xsl:with-param name="frame" select="$frame" as="xs:string"/>
                </xsl:apply-templates>
            </xsl:if>
            <xsl:if test="following-sibling::*[contains(@class, ' topic/stentry ')]">
                <xsl:apply-templates select="." mode="simpletableVerticalBorders">
                    <xsl:with-param name="frame" select="$frame" as="xs:string"/>
                </xsl:apply-templates>
            </xsl:if>

            <xsl:choose>
                <xsl:when test="number(ancestor::*[contains(@class, ' topic/simpletable ')][1]/@keycol) = $entryCol">
                    <fo:block xsl:use-attribute-sets="strow.stentry__keycol-content">
                        <xsl:apply-templates select="." mode="ancestor-start-flag"/>
                        <xsl:apply-templates/>
                        <xsl:apply-templates select="." mode="ancestor-end-flag"/>
                    </fo:block>
                </xsl:when>
                <xsl:otherwise>
                    <fo:block xsl:use-attribute-sets="strow.stentry__content">
                        <xsl:apply-templates select="." mode="ancestor-start-flag"/>
                        <xsl:apply-templates/>
                        <xsl:apply-templates select="." mode="ancestor-end-flag"/>
                    </fo:block>
                </xsl:otherwise>
            </xsl:choose>
        </fo:table-cell>
    </xsl:template>

    <xsl:template match="*" mode="simpletableHorizontalBorders">
        <xsl:param name="frame" select="(ancestor-or-self::*[contains(@class, ' topic/simpletable ')][1]/@frame, $table.frame-default)[1]"
            as="xs:string"/>
        <xsl:call-template name="generateSimpleTableHorizontalBorders">
            <xsl:with-param name="frame" select="$frame"/>
        </xsl:call-template>
    </xsl:template>
    <xsl:template match="*" mode="simpletableTopBorder">
        <xsl:param name="frame" select="(ancestor-or-self::*[contains(@class, ' topic/simpletable ')][1]/@frame, $table.frame-default)[1]"
            as="xs:string"/>
        <xsl:if test="$frame = ('all', 'topbot', 'top')">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__top'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    <xsl:template match="*" mode="simpletableSideBorders">
        <xsl:param name="frame" select="(ancestor-or-self::*[contains(@class, ' topic/simpletable ')][1]/@frame, $table.frame-default)[1]"
            as="xs:string"/>
        <xsl:if test="$frame = ('all', 'topbot', 'sides')">
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__left'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="'__tableframe__right'"/>
                <xsl:with-param name="path" select="$tableAttrs"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    <xsl:template match="*" mode="simpletableVerticalBorders">
        <xsl:param name="frame" select="(ancestor-or-self::*[contains(@class, ' topic/simpletable ')][1]/@frame, $table.frame-default)[1]"
            as="xs:string"/>
        <xsl:call-template name="generateSimpleTableVerticalBorders">
            <xsl:with-param name="frame" select="$frame"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template name="generateSimpleTableHorizontalBorders">
        <xsl:param name="frame" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$frame = ('all', 'topbot', 'sides') or empty($frame)">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'__tableframe__bottom'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="generateSimpleTableVerticalBorders">
        <xsl:param name="frame" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$frame = ('all', 'topbot', 'sides') or empty($frame)">
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="'__tableframe__right'"/>
                    <xsl:with-param name="path" select="$tableAttrs"/>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="topicrefAttsNoToc">
      <!--TODO-->
    </xsl:template>

    <xsl:template name="topicrefAtts">
      <!--TODO-->
    </xsl:template>

    <xsl:template name="selectAtts">
      <!--TODO-->
    </xsl:template>

    <xsl:template name="globalAtts">
      <!--TODO-->
    </xsl:template>

</xsl:stylesheet>
