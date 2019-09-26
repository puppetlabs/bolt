<?xml version="1.0" encoding="UTF-8"?>
<!--
    ============================================================
    Copyright (c) 2007 Antenna House, Inc. All rights reserved.
    Antenna House is a trademark of Antenna House, Inc.
    URL    : http://www.antennahouse.com/
    E-mail : info@antennahouse.com
    ============================================================
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">

    <xsl:attribute-set name="__toc__mini__table">
        <xsl:attribute name="table-layout">fixed</xsl:attribute>
        <xsl:attribute name="width">100%</xsl:attribute>
        <xsl:attribute name="page-break-after">always</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__mini__table__body">
        <!-- BUGFIX: 'break-after' is is not applied to fo:table-body in XSL 1.1 2007/10/15 -->
        <!--xsl:attribute name="page-break-after">always</xsl:attribute-->
    </xsl:attribute-set>

</xsl:stylesheet>
