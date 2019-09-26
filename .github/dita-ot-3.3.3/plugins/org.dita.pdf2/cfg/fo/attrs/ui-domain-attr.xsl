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

    <xsl:attribute-set name="uicontrol">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
        <xsl:attribute name="line-height">100%</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="wintitle">
        <xsl:attribute name="font-weight">bold</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="menucascade">
        <xsl:attribute name="line-height">100%</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="shortcut">
        <xsl:attribute name="text-decoration">underline</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="screen" use-attribute-sets="base-font">
        <xsl:attribute name="space-before">1.2em</xsl:attribute>
        <xsl:attribute name="space-after">0.8em</xsl:attribute>
        <xsl:attribute name="white-space-treatment">preserve</xsl:attribute>
        <xsl:attribute name="white-space-collapse">false</xsl:attribute>
        <xsl:attribute name="linefeed-treatment">preserve</xsl:attribute>
        <xsl:attribute name="wrap-option">wrap</xsl:attribute>
        <xsl:attribute name="background-color">#f0f0f0</xsl:attribute>
        <xsl:attribute name="font-family">monospace</xsl:attribute>
        <xsl:attribute name="line-height">106%</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="screen__top">
        <xsl:attribute name="leader-pattern">rule</xsl:attribute>
        <xsl:attribute name="leader-length">5.65in</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="screen__bottom">
        <xsl:attribute name="leader-pattern">rule</xsl:attribute>
        <xsl:attribute name="leader-length">5.65in</xsl:attribute>
    </xsl:attribute-set>

</xsl:stylesheet>