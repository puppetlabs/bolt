<?xml version="1.0"?>

<!-- 
Copyright © 2004-2006 by Idiom Technologies, Inc. All rights reserved. 
IDIOM is a registered trademark of Idiom Technologies, Inc. and WORLDSERVER
and WORLDSTART are trademarks of Idiom Technologies, Inc. All other 
trademarks are the property of their respective owners. 

IDIOM TECHNOLOGIES, INC. IS DELIVERING THE SOFTWARE &quot;AS IS,&quot; WITH 
ABSOLUTELY NO WARRANTIES WHATSOEVER, WHETHER EXPRESS OR IMPLIED,  AND IDIOM
TECHNOLOGIES, INC. DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE AND WARRANTY OF NON-INFRINGEMENT. IDIOM TECHNOLOGIES, INC. SHALL NOT
BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, COVER, PUNITIVE, EXEMPLARY,
RELIANCE, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF 
ANTICIPATED PROFIT), ARISING FROM ANY CAUSE UNDER OR RELATED TO  OR ARISING 
OUT OF THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF IDIOM
TECHNOLOGIES, INC. HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. 

Idiom Technologies, Inc. and its licensors shall not be liable for any
damages suffered by any person as a result of using and/or modifying the
Software or its derivatives. In no event shall Idiom Technologies, Inc.&apos;s
liability for any damages hereunder exceed the amounts received by Idiom
Technologies, Inc. as a result of this transaction.

These terms and conditions supersede the terms and conditions in any
licensing agreement to the extent that such terms and conditions conflict
with those set forth herein.

This file is part of the DITA Open Toolkit project.
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">

    <xsl:attribute-set name="codeph">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="codeblock" use-attribute-sets="pre">
        <xsl:attribute name="keep-with-previous.within-page">always</xsl:attribute>
        <xsl:attribute name="start-indent">6pt + from-parent(start-indent)</xsl:attribute>
        <xsl:attribute name="end-indent">6pt + from-parent(end-indent)</xsl:attribute>
        <xsl:attribute name="padding">6pt</xsl:attribute>
        <xsl:attribute name="background-color">#f0f0f0</xsl:attribute>
        <xsl:attribute name="wrap-option">wrap</xsl:attribute>
        <xsl:attribute name="hyphenation-character">&#x25BA;</xsl:attribute>
    </xsl:attribute-set>
  
    <xsl:attribute-set name="codeblock__top">
        <xsl:attribute name="leader-pattern">rule</xsl:attribute>
        <xsl:attribute name="leader-length">100%</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="codeblock__bottom">
        <xsl:attribute name="leader-pattern">rule</xsl:attribute>
        <xsl:attribute name="leader-length">100%</xsl:attribute>
    </xsl:attribute-set>
  
    <xsl:attribute-set name="codeblock.line-number">
      <xsl:attribute name="font-size">75%</xsl:attribute>
      <xsl:attribute name="font-weight">normal</xsl:attribute>
      <xsl:attribute name="font-style">normal</xsl:attribute>
      <xsl:attribute name="color">gray</xsl:attribute>
      <xsl:attribute name="padding-end">1em</xsl:attribute>
    </xsl:attribute-set>
    
  <xsl:attribute-set name="codeblock.whitespace">
    <xsl:attribute name="color">#C0C0C0</xsl:attribute>
  </xsl:attribute-set>

    <xsl:attribute-set name="option">
    </xsl:attribute-set>

    <xsl:attribute-set name="var">
        <xsl:attribute name="font-style">italic</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="parmname">
    </xsl:attribute-set>

    <xsl:attribute-set name="synph">
    </xsl:attribute-set>

    <xsl:attribute-set name="oper">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="delim">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="sep">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="apiname">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="parml">
    </xsl:attribute-set>

    <xsl:attribute-set name="plentry">
    </xsl:attribute-set>

    <xsl:attribute-set name="pt">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
        <xsl:attribute name="text-indent">0em</xsl:attribute>
        <xsl:attribute name="end-indent">24pt</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="pt__content">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="pd">
        <xsl:attribute name="space-before">0.3em</xsl:attribute>
        <xsl:attribute name="space-after">0.5em</xsl:attribute>
        <xsl:attribute name="start-indent">72pt</xsl:attribute>
        <xsl:attribute name="end-indent">24pt</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="synblk">
    </xsl:attribute-set>

    <xsl:attribute-set name="synnoteref">
        <xsl:attribute name="baseline-shift">super</xsl:attribute>
        <xsl:attribute name="font-size">75%</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="synnote">
        <xsl:attribute name="baseline-shift">super</xsl:attribute>
        <xsl:attribute name="font-size">75%</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="syntaxdiagram">
    </xsl:attribute-set>

    <xsl:attribute-set name="fragment">
    </xsl:attribute-set>

    <xsl:attribute-set name="syntaxdiagram.title">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
        <xsl:attribute name="keep-with-next.within-column">always</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="kwd">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="kwd__default">
        <xsl:attribute name="text-decoration">underline</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="fragref">
        <xsl:attribute name="font-family">monospace</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="fragment.title">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="fragment.group">
    </xsl:attribute-set>

    <xsl:attribute-set name="syntaxdiagram.group">
    </xsl:attribute-set>

</xsl:stylesheet>