<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2007, 2009 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<!-- Updates:
     20090421 robander: Updated so that "flagrules" in all templates
              specifies a default. Can simplify calls from other XSL
              to these templates, with a slight trade-off in processing
              time. Default for "conflictexist" simplifies XSL
              elsewhere with no processing trade-off.
              -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  version="2.0"  
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
  xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
  exclude-result-prefixes="dita2html ditamsg xs">
 
 <xsl:template name="getrules">
   <xsl:variable name="domains" select="normalize-space(ancestor-or-self::*[contains(@class,' topic/topic ')][1]/@domains)"
     as="xs:string"/>
  <xsl:variable name="tmp_props">
   <xsl:call-template name="getExtProps">
    <xsl:with-param name="domains" select="$domains"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="props" select="substring-after($tmp_props, ',')" as="xs:string"/>
  <!-- Test for the flagging attributes. If found, call 'gen-prop' with the values to use. Otherwise return -->
  <xsl:if test="@audience and not($FILTERFILE='')">
   <xsl:call-template name="gen-prop">
    <xsl:with-param name="flag-att" select="'audience'"/>
    <xsl:with-param name="flag-att-val" select="@audience"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:if test="@platform and not($FILTERFILE='')">
   
   <xsl:call-template name="gen-prop">
    <xsl:with-param name="flag-att" select="'platform'"/>
    <xsl:with-param name="flag-att-val" select="@platform"/>
   </xsl:call-template>
   
  </xsl:if>
  <xsl:if test="@product and not($FILTERFILE='')">
   <xsl:call-template name="gen-prop">
    <xsl:with-param name="flag-att" select="'product'"/>
    <xsl:with-param name="flag-att-val" select="@product"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:if test="@otherprops and not($FILTERFILE='')">
   <xsl:call-template name="gen-prop">
    <xsl:with-param name="flag-att" select="'otherprops'"/>
    <xsl:with-param name="flag-att-val" select="@otherprops"/>
   </xsl:call-template>
  </xsl:if>
  
  <xsl:if test="@rev and not($FILTERFILE='')">
   <xsl:call-template name="gen-prop">
    <xsl:with-param name="flag-att" select="'rev'"/>
    <xsl:with-param name="flag-att-val" select="@rev"/>
   </xsl:call-template>
  </xsl:if>
  
  <xsl:if test="not($props='') and not($FILTERFILE='')">
   <xsl:call-template name="ext-getrules">
    <xsl:with-param name="props" select="$props"/>
   </xsl:call-template>
  </xsl:if>
 </xsl:template>
 
 <xsl:template name="getExtProps">
  <xsl:param name="domains"/>
  <xsl:choose>
   <xsl:when test="contains($domains, 'a(props')">
    <xsl:text>,</xsl:text><xsl:value-of select="normalize-space(concat('props',substring-before(substring-after($domains,'a(props'), ')')))"/>
    <xsl:call-template name="getExtProps">
     <xsl:with-param name="domains" select="substring-after(substring-after($domains,'a(props'), ')')"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise/>
  </xsl:choose>
 </xsl:template>
 
 <xsl:template name="ext-getrules">
  <xsl:param name="props"/>
  <xsl:choose>
   <xsl:when test="contains($props,',')">
    <xsl:variable name="propsValue">
     <xsl:call-template name="getPropsValue">
      <xsl:with-param name="propsPath" select="substring-before($props,',')"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="propName">
     <xsl:call-template name="getLastPropName">
      <xsl:with-param name="propsPath" select="substring-before($props,',')"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($propsValue='')">
     <xsl:call-template name="ext-gen-prop">
      <xsl:with-param name="flag-att-path" select="substring-before($props,',')"/>
      <xsl:with-param name="flag-att-val" select="$propsValue"/>
     </xsl:call-template>
    </xsl:if>
    <xsl:call-template name="ext-getrules">
     <xsl:with-param name="props" select="substring-after($props,',')"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="propsValue">
     <xsl:call-template name="getPropsValue">
      <xsl:with-param name="propsPath" select="$props"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="propName">
     <xsl:call-template name="getLastPropName">
      <xsl:with-param name="propsPath" select="$props"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($propsValue='')">
     <xsl:call-template name="ext-gen-prop">
      <xsl:with-param name="flag-att-path" select="$props"/>
      <xsl:with-param name="flag-att-val" select="$propsValue"/>
     </xsl:call-template>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 <!-- Use passed attr value to mark each active flag. -->
 <xsl:template name="ext-gen-prop">
  <xsl:param name="flag-att-path"/>
  <xsl:param name="flag-att-val"/>
  <xsl:variable name="propName">
   <xsl:call-template name="getLastPropName">
    <xsl:with-param name="propsPath" select="$flag-att-path"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="flag-result">
   <xsl:call-template name="gen-prop">
    <xsl:with-param name="flag-att" select="$propName"/>
    <xsl:with-param name="flag-att-val" select="$flag-att-val"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="$flag-result/prop">
    <xsl:copy-of select="$flag-result"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="contains($flag-att-path,' ')">
     <xsl:call-template name="ext-gen-prop">
      <xsl:with-param name="flag-att-path" select="normalize-space(substring-before($flag-att-path, $propName))"/>
      <xsl:with-param name="flag-att-val" select="$flag-att-val"/>
     </xsl:call-template>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 <xsl:template name="gen-prop">
  <xsl:param name="flag-att"/>     <!-- attribute name -->
  <xsl:param name="flag-att-val"/> <!-- content of attribute -->
  
  <!-- Determine the first flag value, which is the value before the first space -->
  <xsl:variable name="firstflag">
   <xsl:choose>
    <xsl:when test="contains($flag-att-val,' ')">
     <xsl:value-of select="substring-before($flag-att-val,' ')"/>
    </xsl:when>
    <xsl:otherwise> <!-- no space, one value -->
     <xsl:value-of select="$flag-att-val"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  
  <!-- Determine the other flag values, after the first space -->
  <xsl:variable name="moreflags">
   <xsl:choose>
    <xsl:when test="contains($flag-att-val,' ')">
     <xsl:value-of select="substring-after($flag-att-val,' ')"/>
    </xsl:when>
    <xsl:otherwise/> <!-- no space, one value -->
   </xsl:choose>
  </xsl:variable>
  
  <xsl:choose> <!-- Ensure there's an image to get, otherwise don't insert anything -->
   <xsl:when test="$flag-att='rev' and $FILTERDOC/val/revprop[@val=$firstflag][@action='flag']">
    <xsl:copy-of select="$FILTERDOC/val/revprop[@val=$firstflag][@action='flag']"/>
   </xsl:when>
   <xsl:when test="$FILTERDOC/val/prop[@att=$flag-att][@val=$firstflag][@action='flag']">
    <xsl:copy-of select="$FILTERDOC/val/prop[@att=$flag-att][@val=$firstflag][@action='flag']"/>
   </xsl:when>
   <xsl:when test="$FILTERDOC/val/prop[@att=$flag-att][not(@val=$firstflag)][@action='flag']">
    
    <xsl:for-each select="$FILTERDOC/val/prop[@att=$flag-att][not(@val=$firstflag)][@action='flag']">
     <!-- get the val -->
     <xsl:variable name="val">
      <xsl:apply-templates select="." mode="getVal"/>
     </xsl:variable>
     <!-- get the backcolor -->
     <xsl:variable name="backcolor">
      <xsl:apply-templates select="." mode="getBgcolor"/>
     </xsl:variable>
     <!-- get the color -->
     <xsl:variable name="color">
      <xsl:apply-templates select="." mode="getColor"/>
     </xsl:variable>
     <!-- get the style -->
     <xsl:variable name="style">
      <xsl:apply-templates select="." mode="getStyle"/>
     </xsl:variable>
     <!-- get child node -->
     <xsl:variable name="childnode">
      <xsl:apply-templates select="." mode="getChildNode"/>
     </xsl:variable>
     <!-- get the location of schemekeydef.xml -->
     <xsl:variable name="KEYDEF-FILE" select="concat($WORKDIR,$PATH2PROJ,'schemekeydef.xml')" as="xs:string"/>
     <!--keydef.xml contains the val  -->
     <xsl:if test="(document($KEYDEF-FILE, /)//*[@keys=$val])">
      <!-- copy needed elements -->
      <xsl:apply-templates select="(document($KEYDEF-FILE, /)//*[@keys=$val])" mode="copy-element">
       <xsl:with-param name="att" select="$flag-att"/>
       <xsl:with-param name="bgcolor" select="$backcolor"/>
       <xsl:with-param name="fcolor" select="$color"/>
       <xsl:with-param name="style" select="$style"/>
       <xsl:with-param name="value" select="$val"/>
       <xsl:with-param name="flag" select="$firstflag"/>
       <xsl:with-param name="childnodes" select="$childnode"/>
      </xsl:apply-templates>
     </xsl:if>
    </xsl:for-each>
   </xsl:when>
   <xsl:otherwise/> <!-- that flag not active -->
  </xsl:choose>
  
  <!-- keep testing other values -->
  <xsl:choose>
   <xsl:when test="string-length($moreflags)>0">
    <!-- more values - call it again with remaining values -->
    <xsl:call-template name="gen-prop">
     <xsl:with-param name="flag-att"><xsl:value-of select="$flag-att"/></xsl:with-param>
     <xsl:with-param name="flag-att-val"><xsl:value-of select="$moreflags"/></xsl:with-param>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise/> <!-- no more values -->
  </xsl:choose>
 </xsl:template>
 
 <!-- copy needed elements -->
 <xsl:template match="*" mode="copy-element">
  <xsl:param name="att"/>
  <xsl:param name="bgcolor"/>
  <xsl:param name="fcolor"/>
  <xsl:param name="style"/>
  <xsl:param name="value"/>
  <xsl:param name="flag"/>
  <xsl:param name="cvffilename" select="@source"/>
  <xsl:param name="childnodes"/>
  <!--get the location of dita.xml.properties-->
  <xsl:variable name="INITIAL-PROPERTIES-FILE"
    select="translate(concat($WORKDIR , $PATH2PROJ , 'subject_scheme.dictionary'), '\', '/')"
    as="xs:string"/>
  
  <xsl:variable name="PROPERTIES-FILE">
   <xsl:choose>
    <xsl:when test="starts-with($INITIAL-PROPERTIES-FILE,'/')">
     <xsl:text>file://</xsl:text><xsl:value-of select="$INITIAL-PROPERTIES-FILE"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:text>file:/</xsl:text><xsl:value-of select="$INITIAL-PROPERTIES-FILE"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <!-- get the scheme list -->
  <!-- check CURRENT File -->
  <xsl:variable name="editedFileName">
   <xsl:call-template name="checkFile">
    <xsl:with-param name="in" select="$CURRENTFILE"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="schemeList">
   <xsl:apply-templates select="document($PROPERTIES-FILE,/)//*[@key=$editedFileName]" mode="check"/>
  </xsl:variable>
  <!-- scheme list contains the scheme file -->
  <xsl:if test="contains($schemeList, $cvffilename)">
   <!-- get the path of scheme file -->
   <xsl:variable name="submfile">
    <xsl:value-of select="$cvffilename"/><xsl:text>.subm</xsl:text>
   </xsl:variable>
   <xsl:variable name="cvffilepath" select="concat($WORKDIR,$PATH2PROJ,$submfile)" as="xs:string"/>
   <xsl:if test="document($cvffilepath,/)//*[@keys=$value]//*[@keys=$flag]">
    <!-- copy the child node for flag and just copy the first element whose keys=$flag-->
    <!--xsl:for-each select="document($cvffilepath,/)//*[@keys=$value]/*"-->
    <xsl:for-each select="document($cvffilepath,/)//*[@keys=$value]//*[@keys=$flag][1]">
     <xsl:element name="prop">
      <xsl:attribute name="att">
       <xsl:value-of select="$att"/>
      </xsl:attribute>
      <xsl:attribute name="val">
       <xsl:value-of select="@keys"/>
      </xsl:attribute>
      <xsl:attribute name="action">
       <xsl:value-of select="'flag'"/>
      </xsl:attribute>
      <xsl:attribute name="backcolor">
       <xsl:value-of select="$bgcolor"/>
      </xsl:attribute>
      <xsl:attribute name="color">
       <xsl:value-of select="$fcolor"/>
      </xsl:attribute>
      <xsl:attribute name="style">
       <xsl:value-of select="$style"/>
      </xsl:attribute>
      <xsl:copy-of select="$childnodes"/>
     </xsl:element>
    </xsl:for-each>
   </xsl:if>
  </xsl:if>
 </xsl:template>
 <!-- check CURRENT File -->
 <xsl:template name="checkFile">
  <xsl:param name="in"/>
  <xsl:choose>
   <xsl:when test="starts-with($in, '.\')">
    <xsl:value-of select="substring-after($in, '.\')"/>
   </xsl:when>
   <!-- The file dir passed in by ant cannot by none -->
   <xsl:when test="starts-with($in, './')">
    <xsl:value-of select="substring-after($in, './')"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$in"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 <!-- get the scheme list -->
 <xsl:template match="*" mode="check">
  <xsl:value-of select="."/>
 </xsl:template>
 <xsl:template match="*" mode="getVal">
  <xsl:value-of select="@val"/>
 </xsl:template>
 <!-- get background color -->
 <xsl:template match="*" mode="getBgcolor">
  <xsl:choose>
   <xsl:when test="@backcolor">
    <xsl:value-of select="@backcolor"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="''"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 <!-- get font color -->
 <xsl:template match="*" mode="getColor">
  <xsl:choose>
   <xsl:when test="@color">
    <xsl:value-of select="@color"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="''"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 <!-- get font style -->
 <xsl:template match="*" mode="getStyle">
  <xsl:choose>
   <xsl:when test="@style">
    <xsl:value-of select="@style"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="''"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 <!-- get child nodes -->
 <xsl:template match="*" mode="getChildNode">
  <xsl:copy-of select="node()"/>
 </xsl:template>
 
 <xsl:template name="getPropsValue">
  <xsl:param name="propsPath"/>
  <xsl:variable name="propName">
   <xsl:call-template name="getLastPropName">
    <xsl:with-param name="propsPath" select="$propsPath"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="@*[name()=$propName]">
    <xsl:value-of select="@*[name()=$propName]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="getGeneralValue">
     <xsl:with-param name="propName" select="$propName"/>
     <xsl:with-param name="propsPath" select="normalize-space(substring-before($propsPath, $propName))"/>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 <xsl:template name="getLastPropName">
  <xsl:param name="propsPath"/>
  <xsl:choose>
   <xsl:when test="contains($propsPath,' ')">
    <xsl:call-template name="getLastPropName">
     <xsl:with-param name="propsPath" select="substring-after($propsPath,' ')"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$propsPath"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 <xsl:template name="getGeneralValue">
  <xsl:param name="propsPath"/>
  <xsl:param name="propName"/>
  <xsl:variable name="propParentName">
   <xsl:call-template name="getLastPropName">
    <xsl:with-param name="propsPath" select="$propsPath"/>
   </xsl:call-template>
  </xsl:variable>
  
  <xsl:choose>
   <xsl:when test="contains(@*[name()=$propParentName],concat($propName,'('))">
    <xsl:value-of select="substring-before(substring-after(@*[name()=$propParentName],concat($propName,'(')),')')"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:choose>
     <xsl:when test="contains($propsPath,' ')">
      <xsl:call-template name="getGeneralValue">
       <xsl:with-param name="propName" select="$propName"/>
       <xsl:with-param name="propsPath" select="normalize-space(substring-before($propsPath, $propParentName))"/>
      </xsl:call-template>
     </xsl:when>
     <xsl:otherwise/>
    </xsl:choose>
   </xsl:otherwise>
  </xsl:choose>
  
 </xsl:template>
 
 <xsl:template name="conflict-check">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:choose>
   <xsl:when test="$flagrules/*">
    <xsl:apply-templates select="$flagrules/*[1]" mode="conflict-check"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="'false'"/>
   </xsl:otherwise>
  </xsl:choose>  
 </xsl:template>
 
 <xsl:template match="prop|revprop" mode="conflict-check">
  <xsl:param name="color"/>
  <xsl:param name="backcolor"/>
  
  <xsl:choose>   
   <xsl:when test="(@color and @color!='' and $color!='' and $color!=@color)or(@backcolor and @backcolor!='' and $backcolor!='' and $backcolor!=@backcolor)">
    <xsl:value-of select="'true'"/>
   </xsl:when>
   <xsl:when test="following-sibling::*">
    <xsl:apply-templates select="following-sibling::*[1]" mode="conflict-check">
     <xsl:with-param name="color" select="@color"/>
     <xsl:with-param name="backcolor" select="@backcolor"/>
    </xsl:apply-templates>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="'false'"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 <xsl:template name="start-flagit">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:apply-templates select="$flagrules/prop[1]" mode="start-flagit"/>
 </xsl:template>
 
 <xsl:template name="end-flagit">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:apply-templates select="$flagrules/prop[last()]" mode="end-flagit"/>
 </xsl:template>
 
 <!-- Use @rev to find the first active flagged revision.
  Return 1 for active.
  Return 0 for non-active. -->
 <xsl:template name="find-active-rev-flag">
  <xsl:param name="allrevs"/>
  
  <!-- Determine the first rev value, which is the value before the first space -->
  <xsl:variable name="firstrev">
   <xsl:choose>
    <xsl:when test="contains($allrevs,' ')">
     <xsl:value-of select="substring-before($allrevs,' ')"/>
    </xsl:when>
    <xsl:otherwise> <!-- no space, one value -->
     <xsl:value-of select="$allrevs"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  
  <!-- Determine the other rev value, after the first space -->
  <xsl:variable name="morerevs">
   <xsl:choose>
    <xsl:when test="contains($allrevs,' ')">
     <xsl:value-of select="substring-after($allrevs,' ')"/>
    </xsl:when>
    <xsl:otherwise/> <!-- no space, one value -->
   </xsl:choose>
  </xsl:variable>
  
  <xsl:choose>
   <xsl:when test="$FILTERDOC/val/revprop[@val=$firstrev][@action='flag']">
    <xsl:value-of select="1"/> <!-- rev active -->
   </xsl:when>
   <xsl:otherwise>              <!-- rev not active -->
    
    <!-- keep testing other values -->
    <xsl:choose>
     <xsl:when test="string-length($morerevs)>0">
      <!-- more values - call it again with remaining values -->
      <xsl:call-template name="find-active-rev-flag">
       <xsl:with-param name="allrevs"><xsl:value-of select="$morerevs"/></xsl:with-param>
      </xsl:call-template>
     </xsl:when>
     <xsl:otherwise> <!-- no more values - none found -->
      <xsl:value-of select="0"/>
     </xsl:otherwise>
    </xsl:choose>
    
   </xsl:otherwise>
  </xsl:choose>
  
 </xsl:template>
 
 <!-- There's a rev attr - test for active rev values -->
 <xsl:template name="start-mark-rev">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:param name="revvalue"/>
  <xsl:variable name="revtest">
   <xsl:call-template name="find-active-rev-flag">
    <xsl:with-param name="allrevs" select="$revvalue"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:if test="$revtest=1">
   <xsl:call-template name="start-revision-flag">
    <xsl:with-param name="flagrules" select="$flagrules"/> 
   </xsl:call-template>
  </xsl:if>
 </xsl:template>
 
 <!-- There's a rev attr - test for active rev values -->
 <xsl:template name="end-mark-rev">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:param name="revvalue"/>
  <xsl:variable name="revtest">
   <xsl:call-template name="find-active-rev-flag">
    <xsl:with-param name="allrevs" select="$revvalue"/>
   </xsl:call-template>
  </xsl:variable>
  <xsl:if test="$revtest=1">
   <xsl:call-template name="end-revision-flag">
    <xsl:with-param name="flagrules" select="$flagrules"/> 
   </xsl:call-template>
  </xsl:if>
 </xsl:template>
 
 <!-- output the beginning revision graphic & ALT text -->
 <!-- Reverse the artwork for BIDI languages -->
 <xsl:template name="start-revision-flag">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:variable name="biditest"> 
   <xsl:call-template name="bidi-area"/>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="$biditest='bidi'">
    <xsl:call-template name="end-revflagit">
     <xsl:with-param name="flagrules" select="$flagrules"/>
    </xsl:call-template>  
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="start-revflagit">
     <xsl:with-param name="flagrules" select="$flagrules"/>
    </xsl:call-template>  
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 
 <!-- output the ending revision graphic & ALT text -->
 <!-- Reverse the artwork for BIDI languages -->
 <xsl:template name="end-revision-flag">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:variable name="biditest">
   <xsl:call-template name="bidi-area"/>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="$biditest='bidi'">
    <xsl:call-template name="start-revflagit">
     <xsl:with-param name="flagrules" select="$flagrules"/>
    </xsl:call-template>  
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="end-revflagit">
     <xsl:with-param name="flagrules" select="$flagrules"/>
    </xsl:call-template>  
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 
 <xsl:template name="end-revflagit">
  <xsl:param name="flagrules">
   <xsl:call-template name="getrules"/>
  </xsl:param>
  <xsl:apply-templates select="$flagrules/revprop[last()]" mode="end-revflagit"/>
 </xsl:template>
 
 
 <xsl:template match="*" mode="ditamsg:conflict-text-style-applied">
  <xsl:call-template name="output-message">
   <xsl:with-param name="id" select="'DOTX054W'"/>
  </xsl:call-template>
 </xsl:template>
 
 <!-- Test for in BIDI area: returns "bidi" when parent's @xml:lang is a bidi language;
  Otherwise, leave blank -->
 <xsl:template name="bidi-area">
  <xsl:param name="parentlang">
   <xsl:call-template name="getLowerCaseLang"/>
  </xsl:param>
  <xsl:variable name="direction">
   <xsl:apply-templates select="." mode="get-render-direction">
    <xsl:with-param name="lang" select="$parentlang"/>
   </xsl:apply-templates>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="$direction='rtl'">bidi</xsl:when>
   <xsl:otherwise/>
  </xsl:choose>
 </xsl:template>
 
 <!-- No flagging attrs allowed to process in phrases - output a message when in debug mode. -->
 <xsl:template name="flagcheck">
  
  <xsl:variable name="domains"
    select="normalize-space(ancestor-or-self::*[contains(@class,' topic/topic ')][1]/@domains)"
    as="xs:string"/>
  <xsl:variable name="props">
   <xsl:if test="contains($domains, 'a(props')">
    <xsl:value-of select="normalize-space(substring-before(substring-after($domains,'a(props'), ')'))"/>
   </xsl:if>
  </xsl:variable>
  
  <xsl:if test="$DBG='yes' and not($FILTERFILE='')">
   <xsl:if test="@audience">
    <xsl:apply-templates select="." mode="ditamsg:cannot-flag-inline-element">
     <xsl:with-param name="attr-name" select="'audience'"/>
    </xsl:apply-templates>
   </xsl:if>
   <xsl:if test="@platform">
    <xsl:apply-templates select="." mode="ditamsg:cannot-flag-inline-element">
     <xsl:with-param name="attr-name" select="'platform'"/>
    </xsl:apply-templates>
   </xsl:if>
   <xsl:if test="@product">
    <xsl:apply-templates select="." mode="ditamsg:cannot-flag-inline-element">
     <xsl:with-param name="attr-name" select="'product'"/>
    </xsl:apply-templates>
   </xsl:if>
   <xsl:if test="@otherprops">
    <xsl:apply-templates select="." mode="ditamsg:cannot-flag-inline-element">
     <xsl:with-param name="attr-name" select="'otherprops'"/>
    </xsl:apply-templates>
   </xsl:if>
   <xsl:if test="not($props='')">
    <xsl:call-template name="ext-flagcheck">
     <xsl:with-param name="props" select="$props"/>
    </xsl:call-template>
   </xsl:if>
  </xsl:if>
 </xsl:template>
 
 <xsl:template name="ext-flagcheck">
  <xsl:param name="props"/>
  <xsl:choose>
   <xsl:when test="contains($props,',')">
    <xsl:variable name="propsValue">
     <xsl:call-template name="getPropsValue">
      <xsl:with-param name="propsPath" select="substring-before($props,',')"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="propName">
     <xsl:call-template name="getLastPropName">
      <xsl:with-param name="propsPath" select="substring-before($props,',')"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($propsValue='')">
     <xsl:apply-templates select="." mode="ditamsg:cannot-flag-inline-element">
      <xsl:with-param name="attr-name" select="$propName"/>
     </xsl:apply-templates>
    </xsl:if>
    
    <xsl:call-template name="ext-flagcheck">
     <xsl:with-param name="props" select="substring-after($props,',')"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="propsValue">
     <xsl:call-template name="getPropsValue">
      <xsl:with-param name="propsPath" select="$props"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="propName">
     <xsl:call-template name="getLastPropName">
      <xsl:with-param name="propsPath" select="$props"/>
     </xsl:call-template>
    </xsl:variable>
    <xsl:if test="not($propsValue='')">
     <xsl:apply-templates select="." mode="ditamsg:cannot-flag-inline-element">
      <xsl:with-param name="attr-name" select="$propName"/>
     </xsl:apply-templates>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>
 

<!-- ===================================================================== -->
</xsl:stylesheet>